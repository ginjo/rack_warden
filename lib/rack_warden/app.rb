# require 'bundler'
# Bundler.require

require 'logger'

module RackWarden
  class App < Sinatra::Base
          
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :exclude_from_return_to, 'login|logout|new|create'
    set :repository_name, :default
    set :database_config => nil
    set :database_default =>  "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :logging, true
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :log_file, ($0[/rails|irb|ruby|rack|server/i] && development? ? $stdout : nil)
    set :log_level => ENV['RACK_WARDEN_LOG_LEVEL'] || (development? ? 'INFO' : 'WARN')
    set :logger, nil
    set :use_common_logger, false
    set :reset_logger, false
    set :sessions, true # Will use parent app sessions. Pass in :key=>'something' to enable RW-specific sessions (maybe).
    set :remember_token_cookie_name, 'rack_warden_remember_token'
    set :user_table_name, 'rack_warden_users'
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    set :login_on_create, true
    set :login_on_activate, false
    set :rw_prefix, '/auth'
    set :mail_options,
    		:delivery_method => :test,
    		:delivery_options => {:from => 'my@email.com'} #, :openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE

    
    # Load config from file, if any exist.
    def self.initialize_config_files(more_config={})
	    Hash.new.tap do |hash|
	      config_files.each {|c| hash.merge!(YAML.load_file(File.join(Dir.pwd, c))) rescue nil}
	      hash.merge! more_config
	      overlay_settings hash
	    end
    end
    
    # Apply new settings on top of existing settings, prepending new views to old views.
    def self.overlay_settings(new_settings)
    	new_views = new_settings.extract(:views).values
    	logger.debug "RW overlay_settings new_views #{new_views.inspect}"
	  	set :views, [new_views, views].flatten.compact.uniq
    	set new_settings
    end
    	
    # Initialize logging.
    def self.initialize_logging(reset=reset_logger)
	    # We take existing log file from settings, enable sync (disables buffering), then put it back in settings.
    	_log_file = !logging && File.new('/dev/null', 'a') || !reset && settings.log_file || File.new(settings.log_path, 'a+')
	    _log_file.sync = true
	    set :log_file, _log_file
	    set :logger, Logger.new(_log_file, 'daily') unless settings.logger && !reset
	    logger.level = eval "Logger::#{log_level}"
	    
	    # Setup Rack::CommonLogger
	    if use_common_logger
	    	mw = @middleware.find {|m| Array(m)[0] == Rack::CommonLogger}
		    #@middleware.delete_if {|m| Array(m)[0] == Rack::CommonLogger}
		    mw ? mw[1]=[_log_file] : use(Rack::CommonLogger, _log_file)
	    end
	    
		  #if logger.level < 2
			  #DataMapper::Logger.new(_log_file)  #$stdout) #App.log_path)
			  DataMapper.logger.instance_variable_set :@log, _log_file
			  DataMapper.logger.instance_variable_set :@level, DataMapper::Logger::Levels[log_level.to_s.downcase.to_sym]
			  # logger.info "RW DataMapper using log_file #{_log_file.inspect}"
		  #end
	    
	    logger.debug "RW initialized logging (level #{logger.level}) #{_log_file.inspect}"
	  rescue
	  	puts "There was an error setting up logging: #{$!}"
	  end
	  
	  # Main RackWarden::App class setup.
	  def self.initialize_app_class
      
	  	initialize_logging
	  	logger.warn "RW initializing RackWarden::App in process #{$0}"
	  	logger.warn "RW running in #{environment} environment"
	  	initialize_config_files
	  	initialize_logging
	  		  	
	    use Rack::Cookies
	    Namespace::NamespacedMethods.prefixed :require_login
	    Sinatra::Namespace::NamespacedMethods.prefixed(:require_login) if Sinatra.const_defined?(:Namespace) && Sinatra::Namespace.const_defined?(:NamespacedMethods)
	    
	    register Namespace
	    register RespondWith
	    	  	
  		# Setup flash if not already
  		# TODO: put code to look for existing session management in rack middlewares (how?). See todo.txt for more.
			use Rack::Flash, :accessorize=>[:rw_error, :rw_success, :rw_test]
				  	
			helpers RackWarden::WardenConfig
			helpers RackWarden::Routes
			
	    helpers RackWardenHelpers
	    helpers UniversalHelpers
	    
	    #Sinatra.register RackWarden
	  end
	  
	  # Creates uri-friendly codes/keys/hashes from raw unfriendly strings (like BCrypt hashes). 
	  def self.uri_encode(string)
	  	URI.encode(Base64.encode64(string))
	  end
	  
	  def self.uri_decode(string)
	  	Base64.decode64(URI.decode(string))
	  end
	  
	  # Generic template rendering. Does not have automatic access to 'controller' environment.
	  # Pass 'object' to be the context of rendered template.
  	# See this for more info on using templates here http://stackoverflow.com/questions/5446283/how-to-use-sinatras-haml-helper-inside-a-model.
	  def self.render_template(template_name, locals_hash={}, object=self )
		  tmpl = settings.views.collect {|v| Tilt.new(File.join(v, template_name)) rescue nil}.compact[0]
		  if tmpl
		  	tmpl.render(object, locals_hash)
		  else
			  App.logger.info "RW self.render_template found no templates to render" 
			  nil
			end
		end
		
		def self.setup_framework(app, *args)
			opts = args.last.is_a?(Hash) ? args.pop : {}
			# Get framework module.
			framework_module = Frameworks.select_framework(app)
			#logger.info "RW selected framework module #{framework_module}"
			
			# Prepend views from framework_module if framework_module exists.
			# TODO: should this line be elsewhere?
			settings.overlay_settings(:views=>framework_module.views_path) if framework_module && ![settings.views, opts[:views]].flatten.include?(false)
			
			# Overlay settings with opts.
			settings.overlay_settings opts				
			
			# Setup framework if framework_module exists.
			framework_module.setup_framework if framework_module
		end
		
  

    # WBR - This will receive params and a block from the parent "use" statement.
    # This middleware app has been modified to process the parent use-block in
    # the context of the RackWarden class. So you can set settings on RackWarden,
    # when you call "use RackWarden"
    # Example:
    #
    # use RackWarden :layout=>:'my_layout' do |rack_warden_instance, app|
  	# 	set :myvar, 'something'
  	#	end
  	#
  	# TODO: Move most of this functionality to a class method, so it can be called from self.registered(app)
  	def initialize(parent_app_instance=nil, *args, &block)
  		super(parent_app_instance, &Proc.new{}) # Must send empty proc, not original proc, since we're calling original block here.
  	  initialization_args = args.dup
  		logger.info "RW new app instance with parent: #{@app}"
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		if app && !settings.initialized
  		  logger.warn "RW initializing settings from app instance"
  		  
  		  
  		  self.class.setup_framework(parent_app_instance, *initialization_args) unless Frameworks.selected_framework

    		    		
  			# Eval the use-block from the parent app, in context of this app.
  			settings.instance_exec(self, &block) if block_given?
  			
 		    # Set global layout (remember to use :layout=>false in your calls to partials).
		    settings.set :erb, :layout=>settings.layout
  			
  			settings.initialize_logging
  			  			
  			logger.info "RW compiled views: #{settings.views.inspect}"
    		
    		settings.set :initialized, true
  		end

  	end # initialize
  	
		# Store this app instance in the env.
		def call(env)  
			logger.debug "RW app.call extending env with Env."
			env.extend Env
			logger.debug "RW app.call next app: #{@app}"
		  
		  # Set this now, so you can access the rw app instance from the endpoint app.
		  logger.debug "RW app.call storing app instance in env['rack_warden_instance'] #{self}"
		  self.request= Rack::Request.new(env)
		  env.rack_warden = self
		  # TODO: Flesh this out with settings and a mini-dsl,
		  # something like:  set :authenticate_with_middleware, {:require_login=>[<conditions>...], :skip_login=>[<conditions>...]}
		  #request.path_info.to_s[/^\/auth/] || require_login
		  
		  # Send to super, then build & process response.
			# resp = Rack::Response.new *super(env).tap{|e| e.unshift e.pop}
			# #resp.set_cookie :wbr_cookie, :value=>"Yay!", :expires=>Time.now+60*10
			# logger.debug "App.call: #{resp.finish}"
			# resp.finish
			super(env)
		end 
		
		# Only initialize app after all above have loaded.
		initialize_app_class

		# To run server with 'ruby app.rb'. Disable if using rack to serve.
		# This really only applies to endpoints, but leaving it hear as example.
  	#run! if app_file == $0
  end # App
  
  # TODO: This is not working:
  #Sinatra::Application.register self
end # RackWarden



