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
    set :rack_authentication, nil
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

    
	  
		register AppClassMethods
		
  

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
  		  
  		  self.class.setup_framework(parent_app_instance, *initialization_args) #unless Frameworks.selected_framework
    		    		
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
			
			# Authenticate here-and-now.		  
		  if !request.path_info.to_s.match(/^\/auth/) && settings.rack_authentication
		  logger.debug "RW rack_authentication for path_info: #{request.path_info}"
		  Array(settings.rack_authentication).each do |rule|
		  	logger.debug "RW rack_authentication rule #{rule}"
		  	(require_login) if rule && request.path_info.to_s.match(Regexp.new rule.to_s)
		  end
		  end
		  
		  # Send to super, then build & process response.
			# resp = Rack::Response.new *super(env).tap{|e| e.unshift e.pop}
			# #resp.set_cookie :wbr_cookie, :value=>"Yay!", :expires=>Time.now+60*10
			# logger.debug "App.call: #{resp.finish}"
			# resp.finish
			super(env)
		end 
		
		# Only initialize app after all above have loaded.
		#initialize_app_class


  end # App
  
  # TODO: This is not working:
  #Sinatra::Application.register self
end # RackWarden



