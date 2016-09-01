# require 'bundler'
# Bundler.require

require 'logger'

module RackWarden
  class App < Sinatra::Base
    Subclasses = Array.new
    
    use Rack::Session::Cookie
    disable :protection if development?
          
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
    # set :sessions, :key => 'rack_warden',
    #     :path => '/',
    #     :expire_after => 14400, # In seconds
    #     :secret => 'skj3l4kgjsl3kkgjlsd0f98slkjrewlksufdjlksefk'
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
	  
	  
    def self.inherited(subclass)
      Subclasses  << subclass
      super
    end
    
	  
	  # See below
		#register RackWardenClassMethods


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
    # 	def initialize(parent_app_instance=nil, *args)
    # 		super(parent_app_instance, &Proc.new{}) # Must send empty proc, not original proc, since we're calling original block here.
    # 	  initialization_args = args.dup
    # 		logger.info "RW App#initialize parent: #{@app}"
    # 		logger.debug "RW App#initialize self: #{self}, args: #{args}, block_given? #{block_given?}"
    # 		opts = args.last.is_a?(Hash) ? args.pop : {}
    # 		
    # 		
    # 		logger.debug "RW App#initialize settings.initialized: #{settings.initialized}"
    # 		if app && !settings.initialized
    # 			#self.class.initialize_settings_from_instance(parent_app_instance, self, *initialization_args)
    # 			if block_given?
    #   			settings.initialize_settings_from_instance(parent_app_instance, self, *initialization_args, &Proc.new)
    #   		else
    #   		  settings.initialize_settings_from_instance(parent_app_instance, self, *initialization_args)
    #   		end
    # 		end
    # 	end # initialize
    
    # This new version of initialize was taken from rack_warden_rom_testing middleware_example.
    def initialize(*args)
      @app = args[0] if args[0]
      @template_cache = Tilt::Cache.new
      
      logger.info "RW #{self.class}#initialize self: #{self}, args:#{args}, block? #{block_given?}"
      block = Proc.new if block_given?
      settings.initialize_settings_from_instance(@app, self, *args[1..-1], &block) if @app && !settings.initialized
      #logger.debug "RW about to call problem 'super', ancestors: #{self.class.ancestors}"
      #super(@app, &block)
      self
    end    
  	
		# Store this app instance in the env.
		# NOTE: Up to this point, the app instance is the same for every call,
		#       since that's what rack does. However, once super(env) is run
		#       at the end of this override method, Sinatra kicks in and creates
		#       a new rw app instance. That's how sinatra works (new app instance for each request).
		def call(env)
			logger.debug "RW App#call self: #{self}, parent app: #{@app}"
			env.extend Env
			
      # 	# Initialize if not already (may only be usefull for stand-alone mode (no parent app)).
      # 	if !settings.initialized
      # 	  logger.debug "RW App#call self: #{self}, calling initialize_settings_from_instance"
      # 		settings.initialize_settings_from_instance(@app, self)
      # 	else
      # 	  logger.debug "RW App#call self: #{self}, not calling initialize_settings_from_instance"
      # 	end
		  
		  # Set this now, so you can access the rw app instance from the endpoint app.
		  logger.debug "RW App#call storing rw app instance #{self} in env['rack_warden_instance']"
		  self.request = Rack::Request.new(env)
		  env.rack_warden = self
		  
		  logger.debug "RW App#call request.path_info: #{request.path_info}"
		  logger.debug "RW App#call session: #{env['rack.session'].inspect}"
			
			# Authenticate here-and-now.
			# TODO: Change this name to Authorize here-and-now ??
			prefix_regex = Regexp.new("^#{settings.rw_prefix}")  
		  if !request.path_info.to_s[prefix_regex] && settings.rack_authentication  # /^\/auth/
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
			logger.debug "RW App#call super(env), self: #{self}"
			super
		end 
		
		# Only initialize app after all above have loaded.
		#initialize_app_class
		register RackWardenClassMethods
		
		before do
		  logger.debug "RW before-request self: #{self}, settings: #{settings}, self.class: #{self.class}"
		end
		
  	after do
      logger.debug "SS after-request env['rack.session']: #{env['rack.session'].inspect}"
      logger.debug "SS after-request env['warden'].session: #{env['warden'].session.inspect}" if env['warden'].authenticated?
  	end


  end # App
  
  # TODO: This is not working:
  #Sinatra::Application.register self
end # RackWarden



