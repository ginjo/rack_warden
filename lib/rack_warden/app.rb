# require 'bundler'
# Bundler.require

require 'logger'

module RackWarden
  class App < Sinatra::Base
    Subclasses = Array.new
    
    # TODO: figure out the best way to initialize sessions.
    #use Rack::Session::Cookie
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
    #set :sessions, true # Will use parent app sessions? I dunno.
    # See initialize_settings_from_instance.
    #
    # set :sessions, :key => 'rack_warden',
    #     :path => '/',
    #     :expire_after => 14400, # In seconds
    #     :secret => 'skj3l4kgjsl3kkgjlsd0f98slkjrewlksufdjlksefk'
    set :remember_token_cookie_name, 'rack_warden_remember_token'
    set :allow_remember_me, false
    set :user_table_name, 'rack_warden_users'
    set :field_maps, {}
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :extra_views, [ File.join(Dir.pwd, "app/views/rack_warden"), File.join(Dir.pwd, "views/rack_warden"), File.join(Dir.pwd,"app/views"), File.join(Dir.pwd,"views")]
    set :initialized, false
    set :login_on_create, true
    set :login_on_activate, false
    set :rw_prefix, '/auth'
    # Note that sinatra settings can be a proc and take args.
    # See 'settings.method(:warden_failure_app).arity or .parameters for introspective info.
    set :warden_failure_app, Proc.new {|*args| self}
    set :warden_failure_action, Proc.new {|*args| ("#{settings.rw_prefix.to_s.gsub(/^\//,'')}/unauthenticated")}
    set :warden_config, nil
    set :mail_options,
    		:delivery_method => :test,
    		:delivery_options => {:from => 'my@email.com'} #, :openssl_verify_mode => OpenSSL::SSL::VERIFY_NONE
    set :omniauth_adapters, Gem.loaded_specs.keys.select{|k| k =~ /omniauth/ && k}
	  
	  
    def self.inherited(subclass)
      Subclasses  << subclass
      super
    end
    
    # This new version of initialize was taken from rack_warden_rom_testing middleware_example.
    def initialize(*args)
      @app = args[0] if args[0]
      @template_cache = Tilt::Cache.new
      
      if @app && !settings.initialized
        logger.info "RW #{self.class}#initialize, self: #{self}, args:#{args}, block? #{block_given?}"
        block = Proc.new if block_given?
        settings.initialize_settings_from_instance(@app, self, *args[1..-1], &block)
        #logger.debug "RW about to call problem 'super', ancestors: #{self.class.ancestors}"
        logger.info "RW initialization complete for app: #{@app}"
      end
      #super(@app, &block)
      self
    end    
  	
		# Store this app instance in the env.
		# NOTE: Up to this point, the app instance is the same for every call,
		#       since that's what rack does. However, once super(env) is run
		#       at the end of this override method, Sinatra kicks in and creates
		#       a dup rw app instance. That's how sinatra works (dup app instance for each request).
		def call(env)
			logger.debug "RW App#call self: #{self}, parent app: #{@app}"
			env.extend RackEnv
			
      # 	# Initialize if not already (may only be usefull for stand-alone mode (no parent app)).
      # 	if !settings.initialized
      # 	  logger.debug "RW App#call self: #{self}, calling initialize_settings_from_instance"
      # 		settings.initialize_settings_from_instance(@app, self)
      # 	else
      # 	  logger.debug "RW App#call self: #{self}, not calling initialize_settings_from_instance"
      # 	end
		  
		  # Dupe this rw app inst, and store in env, so you can access the rw app instance from the endpoint app.
		  # The super 'call' also dupes the inst, but so far it isn't causing problems.
		  new_inst = self.dup
		  new_inst.instance_eval do
  		  self.request = Rack::Request.new(env)
  		  
  		  unless env.rack_warden
    		  logger.debug "RW App#call storing rw app new_inst #{self} in env['rack_warden_instance']"
    		  env.rack_warden = self
  		  end
  		  
  		  logger.debug "RW App#call request.path_info: #{request.path_info}"
  		  logger.debug "RW App#call session: #{session.inspect}"
  			
  			# Authenticate here-and-now.
  			# TODO: Change this name to Authorize here-and-now ??
  			prefix_regex = Regexp.new("^#{settings.rw_prefix}")  
  		  if settings.rack_authentication && !request.script_name.to_s[prefix_regex] && !request.path_info.to_s[prefix_regex]   # /^\/auth/
  			  logger.debug "RW App#call rack_authentication for path_info: #{request.path_info}"
  			  Array(settings.rack_authentication).each do |rule|
  			  	logger.debug "RW App#call rack_authentication rule #{rule}"
  			  	(new_inst.require_login) if rule && request.path_info.to_s.match(Regexp.new rule.to_s)
  			  end
  		  end
  		  
  		  # Send to super, then build & process response.
  			# resp = Rack::Response.new *super(env).tap{|e| e.unshift e.pop}
  			# #resp.set_cookie :wbr_cookie, :value=>"Yay!", :expires=>Time.now+60*10
  			# logger.debug "App.call: #{resp.finish}"
  			# resp.finish
  			#
        # logger.debug "RW App#call super(env), self: #{self}"
        # super
        logger.debug "RW App#call super(env), self: #{self}"
        super
      end # inst-eval
		end # call
		
		# Only initialize app after all above have loaded.
		#initialize_app_class
		register RackWardenClassMethods
		
		before do
		  logger.debug "RW before-request self: #{self}, settings: #{settings}, self.class: #{self.class}"
		end
		
  	after do
      logger.debug "RW after-request session: #{session.inspect}"
      logger.debug "RW after-request params: #{params}"
      #logger.debug "SS after-request env['warden'].session: #{env['warden'].session.inspect}" if env['warden'].authenticated?
  	end


  end # App
  
  # TODO: This is not working:
  #Sinatra::Application.register self
end # RackWarden



