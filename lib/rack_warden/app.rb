# require 'bundler'
# Bundler.require

require 'logger'

module RackWarden
  class App < Sinatra::Base
          
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :exclude_from_return_to, 'login|logout|new|create|activate|unauthenticated|error|failure|(.*\/callback)'
    set :repository_name, :default
    set :database_config, nil
    set :database_default,  "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :disable_erubis, false # Had to be true for Tilt 1.3, or if erubis is loaded
    set :recaptcha, {}
    set :require_login, false   # was nil, changing default to no-security, so must declare in main app.
    set :rack_authentication, nil
    set :allow_public_signup, false
    set :flash_accessories, []
    set :logging, true
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :log_file, ($0[/rails|irb|ruby|rack|server/i] && development? ? $stdout : nil)
    set :log_level => ENV['RACK_WARDEN_LOG_LEVEL'] || (development? ? 'INFO' : 'WARN')
    set :logger, nil
    set :use_common_logger, false
    set :reset_logger, false
    #set :sessions, true # Will use parent app sessions.
      #   Pass in :key=>'something' to enable RW-specific sessions (maybe).
      #   See class helpers for newer session declaration.
      #   Really? Is all this true?
    set :sessions, :key => 'rack_warden',
        :path => '/',
        :expire_after => 14400, # In seconds
        :secret => 'skj3l4kgjsl3kkgjlsd0f98slkjrewlksufdjlksefk'
    set :remember_token_cookie_name, 'rack_warden_remember_token'
    set :user_table_name, 'rack_warden_users'
    set :field_maps, {}
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    set :login_on_create, true
    set :login_on_activate, false
    set :rw_prefix, '/auth'
    set :mail_options,
    		:delivery_method => :test,
    		:delivery_options => {:from => 'my@email.com'} #, :openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE
    set :omniauth_adapters, Gem.loaded_specs.keys.select{|k| k =~ /omniauth/ && k}
	  
		register AppClassMethods


    # NOTE: I think this behavior description & example are not quite correct any more.
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
  		logger.info "RW App#initialize parent: #{@app}"
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		
  		
  		
  		if app && !settings.initialized
  			self.class.initialize_settings_from_instance(parent_app_instance, self, *initialization_args)
# 		  logger.warn "RW initializing settings from app instance with args: #{initialization_args.inspect}"
# 		  
# 		  self.class.setup_framework(parent_app_instance, *initialization_args) #unless Frameworks.selected_framework
#   		    		
# 			# Eval the use-block from the parent app, in context of this app.
# 			settings.instance_exec(self, &block) if block_given?
# 			
# 		    # Set global layout (remember to use :layout=>false in your calls to partials).
# 		    logger.debug "RW App#initialize setting erb layout: #{settings.layout}"
# 	    settings.set :erb, :layout=>settings.layout
# 			
# 			settings.initialize_logging
# 			  			
# 			logger.info "RW compiled views: #{settings.views.inspect}"
#   		
#   		settings.set :initialized, true
  		end

  	end # initialize
  	
		# Store this app instance in the env.
		# NOTE: Up to this point, the app instance is the same for every call,
		#       since that's what rack does. However, once super(env) is run
		#       at the end of this override method, Sinatra kicks in and creates
		#       a new rw app instance. That's how sinatra works (new app instance for each request).
		def call(env)
			logger.debug "RW App#call parent app: #{@app}"
			env.extend Env
			
			# Initialize if not already (may only be usefull for stand-alone mode (no parent app)).
  		if !settings.initialized
  			self.class.initialize_settings_from_instance(@app, self)
  		end
		  
		  # Set this now, so you can access the rw app instance from the endpoint app.
		  logger.debug "RW App#call storing app instance #{self} in env['rack_warden_instance']"
		  self.request = Rack::Request.new(env)
		  env.rack_warden = self
			
			# Authenticate here-and-now.		  
		  if !request.path_info.to_s.match(/^\/auth/) && settings.rack_authentication
			  logger.debug "RW App#call rack_authentication for path_info: #{request.path_info}"
			  Array(settings.rack_authentication).each do |rule|
			  	logger.debug "RW App#call rack_authentication rule #{rule}"
			  	(require_login) if rule && request.path_info.to_s.match(Regexp.new rule.to_s)
			  end
		  end
		  
		  # Send to super, then build & process response.
			# resp = Rack::Response.new *super(env).tap{|e| e.unshift e.pop}
			# #resp.set_cookie :wbr_cookie, :value=>"Yay!", :expires=>Time.now+60*10
			# logger.debug "App.call: #{resp.finish}"
			# resp.finish
			rslt = super(env)
			#logger.debug "RW App#call super(env) result #{rslt}"
			rslt
		end 
		
		# Only initialize app after all above have loaded.
		#initialize_app_class
		
		before do
		  logger.debug "RW request self: #{self}"
		end


  end # App
  
  # TODO: This is not working:
  #Sinatra::Application.register self
end # RackWarden



