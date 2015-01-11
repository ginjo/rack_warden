# require 'bundler'
# Bundler.require

module RackWarden
  class App < Sinatra::Base
        
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :database_config => nil  #, "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :database_default => "sqlite3::memory:"   #"sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :log_file, ($0[/rails|irb/i] && development? ? $stdout : nil)
    set :log_level, (development? ? Logger::DEBUG : Logger::INFO)
    set :logger, nil
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    
    # Load config from file, if any exist.
    def self.initialize_config(more_config={})
	    Hash.new.tap do |hash|
	      config_files.each {|c| hash.merge!(YAML.load_file(File.join(Dir.pwd, c))) rescue nil}
	      prepend_views(hash.extract :views)
	      hash.merge! more_config
	      set hash
	    end
    end
    
    # Initialize Logging
    def self.initialize_logging
	    enable :logging
	    # We take existing log file from settings, enable sync (disables buffering), and put it back in settings.
    	_log_file = settings.log_file || File.new(settings.log_path, 'a+')
	    _log_file.sync = true
	    set :log_file, _log_file
	    set :logger, Logger.new(_log_file, 'daily') unless settings.logger
	    logger.level = log_level
	    use Rack::CommonLogger, _log_file
	  rescue
	  	puts "there was an error setting up the loggers #{$!}"
	  end
	  
	  def self.prepend_views(new_views)
	  	puts "RW prepend_views #{new_views.inspect}"
	  	new_views = new_views.values if new_views.is_a?(Hash)
	  	set :views, [new_views, views].flatten.compact.uniq
	  end
	  
	  
	  
		initialize_config
		initialize_logging
	  
	  enable :sessions
    register Sinatra::Flash
	  
		include RackWarden::WardenConfig
		include RackWarden::Routes
		
    helpers RackWardenHelpers
    helpers UniversalHelpers
  
  
  
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
  		logger.info "RW new instance with parent: #{@app}"
  		# extract options.
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		if app && !settings.initialized
  		  logger.info "RW initializing settings"
  		  
  			# Do framework setup.
  			framework_module = Frameworks::Base.select_framework(binding)
    		logger.info "RW selected framework module #{framework_module}"
  		  
  		  # Prepend views from opts.
  			views_from_use_opts = (opts.extract :views)
  			logger.debug "RW views_from_use_opts #{views_from_use_opts}"
				
  			# Set app settings with remainder of opts.
  			settings.set opts if opts.any?  			

    		if framework_module
    			settings.prepend_views(framework_module.views_path) unless settings.views==false || opts[:views]==false
      		framework_module.setup_framework      		
      		logger.info "RW compiled views: #{settings.views.inspect}"
    		end
    		
    		settings.prepend_views views_from_use_opts
    		
  			# Eval the use-block from the parent app, in context of this app.
  			settings.instance_exec(self, &block) if block_given?
    		
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

		# To run server with 'ruby app.rb'. Disable if using rack to serve.
		# This really only applies to endpoints, but leaving it hear as example.
  	#run! if app_file == $0
  end # App 
end # RackWarden


