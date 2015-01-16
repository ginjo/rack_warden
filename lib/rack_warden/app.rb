# require 'bundler'
# Bundler.require

require 'logger'

module RackWarden
  class App < Sinatra::Base
          
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :database_config => nil  #, "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :database_default =>  "sqlite3::memory:?cache=shared"   #"sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"  #{:adapter=>"in_memory"}
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :logging, true
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :log_file, ($0[/rails|irb|ruby|rack|server/i] && development? ? $stdout : nil)
    set :log_level => ENV['RACK_WARDEN_LOG_LEVEL'] || (development? ? 'INFO' : 'WARN')
    set :logger, nil
    set :use_common_logger, true
    set :reset_logger, false
    set :sessions, nil # Will use parent app sessions. Pass in :key=>'something' to enable RW-specific sessions.
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    
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
	    
		  if logger.level < 2
			  ### CAUTION - There may be a file conflict between this and rack::commonlogger.
			  DataMapper::Logger.new(_log_file)  #$stdout) #App.log_path)
			  logger.info "RW DataMapper using log_file #{_log_file.inspect}"
		  end
	    
	    logger.info "RW initialized logging (level #{logger.level}) #{_log_file.inspect}"
	  rescue
	  	puts "There was an error setting up logging: #{$!}"
	  end
	  
	  # Main RackWarden::App class setup.
	  def self.initialize_app
      
	  	initialize_logging
	  	logger.warn "RW initializing RackWarden::App in process #{$0}"
	  	initialize_config_files
	  	initialize_logging
	  	
  		# Setup flash if not already
  		# TODO: put code to look for existing session management in rack middlewares (how?). See todo.txt for more.
			use Rack::Flash, :accessorize=>[:rw_error, :rw_success]
	  	
			include RackWarden::WardenConfig
			include RackWarden::Routes
			
	    helpers RackWardenHelpers
	    helpers UniversalHelpers
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
  	def initialize(parent_app_instance=nil, *args, &block)
  		super(parent_app_instance, &Proc.new{}) # Must send empty proc, not original proc, since we're calling original block here.
  	  initialization_args = args.dup
  		logger.info "RW new app instance with parent: #{@app}"
  		# extract options.
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		if app && !settings.initialized
  		  logger.warn "RW initializing settings from app instance"
  		  
  			# Get framework module.
  			framework_module = Frameworks::Base.select_framework(binding)
    		logger.info "RW selected framework module #{framework_module}"
    		
    		# Prepend views from framework_module if framework_module exists.
  			settings.overlay_settings(:views=>framework_module.views_path) if framework_module && ![settings.views, opts[:views]].flatten.include?(false)
  		  
  		  # Overlay settings with opts.
  			settings.overlay_settings opts				
	
				# Setup framework if framework_module exists.
    		framework_module.setup_framework if framework_module
    		    		
  			# Eval the use-block from the parent app, in context of this app.
  			settings.instance_exec(self, &block) if block_given?
  			
  			settings.initialize_logging
  			
  			logger.info "RW compiled views: #{settings.views.inspect}"
    		
    		settings.set :initialized, true
  		end

  	end # initialize
  	
		# Store this app instance in the env.
		def call(env)  
			#logger.info "RW instance.app #{app}"
		  #logger.info "RW instance.call(env) #{env.to_yaml}"
		  env['rack_warden_instance'] = self
		  super(env)
		end 
		
		# Only initialize app after all above have loaded.
		initialize_app

		# To run server with 'ruby app.rb'. Disable if using rack to serve.
		# This really only applies to endpoints, but leaving it hear as example.
  	#run! if app_file == $0
  end # App 
end # RackWarden


