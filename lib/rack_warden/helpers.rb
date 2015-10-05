module RackWarden


	module AppClassMethods
	
		def self.registered(app)
			app.initialize_app_class
		end
	
	  # Main RackWarden::App class setup.
	  def initialize_app_class
      
	  	initialize_logging
	  	logger.warn "RW AppClassMethods.initialize_app_class environment: #{environment}, process: #{$0}"
	  	initialize_config_files
	  	initialize_logging
	  		  	
	    use Rack::Cookies
	    RackWarden::Namespace::NamespacedMethods.prefixed :require_login
	    Sinatra::Namespace::NamespacedMethods.prefixed(:require_login) if Sinatra.const_defined?(:Namespace) && Sinatra::Namespace.const_defined?(:NamespacedMethods)
	    
	    register RackWarden::Namespace
	    register RackWarden::RespondWith
	    
	    # Erubis/tilt/respond_with don't play well together in older ruby/rails.
	    if disable_erubis
		    template_engines.delete :erubis
		    Tilt.mappings['erb'].delete Tilt::ErubisTemplate
			end
	    	  	
  		# Setup flash if not already
  		# TODO: put code to look for existing session management in rack middlewares (how?). See todo.txt for more.
			use Rack::Flash, :accessorize=>[:rw_error, :rw_success, :rw_test]
				  	
			helpers RackWarden::WardenConfig
			helpers RackWarden::Routes
			
	    helpers RackWardenHelpers
	    helpers UniversalHelpers
	    
	  end
	  
	  # This should generally only run once, but that is left up to the caller (the app instance).
	  def initialize_settings_from_instance(parent_app_instance, rw_app_instance, *initialization_args)
			logger.warn "RW AppClassMethods.initialize_settings_from_instance parent_app_instance: #{parent_app_instance}, args: #{initialization_args.inspect}"
			
			setup_framework(parent_app_instance, *initialization_args)
			    		
			# Eval the use-block from the parent app, in context of this app.
			#settings.instance_exec(rw_app_instance, &block) if block_given?
			# Eval the use-block from the parent app, in context of the parent app instance.
			yield rw_app_instance if block_given?
			
		  # Set global layout (remember to use :layout=>false in your calls to partials).
		  logger.debug "RW AppClassMethods.initialize_settings_from_instance setting erb layout: #{settings.layout}"
			settings.set :erb, :layout=>settings.layout
			
			settings.initialize_logging
			  			
			logger.info "RW AppClassMethods.initialize_settings_from_instance compiled views: #{settings.views.inspect}"
			
			settings.set :initialized, true	  
	  end
		
		def setup_framework(app, *args)
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

    # Load config from file, if any exist.
    def initialize_config_files(more_config={})
	    Hash.new.tap do |hash|
	      config_files.each {|c| hash.merge!(YAML.load_file(File.join(Dir.pwd, c))) rescue nil}
	      hash.merge! more_config
	      overlay_settings hash
	    end
    end
    
    # Apply new settings on top of existing settings, prepending new views to old views.
    def overlay_settings(new_settings)
    	new_views = new_settings.extract(:views).values
    	logger.debug "RW AppClassMethods.overlay_settings new_views #{new_views.inspect}"
	  	set :views, [new_views, views].flatten.compact.uniq
    	set new_settings
    end
    	
    # Initialize logging.
    def initialize_logging(reset=reset_logger)
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
	    
	    logger.debug "RW AppClassMethods.initialize_logging level: #{logger.level}, _log_file: #{_log_file.inspect}"
	  rescue
	  	puts "There was an error setting up logging: #{$!}"
	  end

	  # Creates uri-friendly codes/keys/hashes from raw unfriendly strings (like BCrypt hashes). 
	  def uri_encode(string)
	  	URI.encode(Base64.encode64(string))
	  end
	  
	  def uri_decode(string)
	  	Base64.decode64(URI.decode(string))
	  end
	  
	  # Generic template rendering. Does not have automatic access to 'controller' environment.
	  # Pass 'object' to be the context of rendered template.
  	# See this for more info on using templates here http://stackoverflow.com/questions/5446283/how-to-use-sinatras-haml-helper-inside-a-model.
	  def render_template(template_name, locals_hash={}, object=self )
		  tmpl = settings.views.collect {|v| Tilt.new(File.join(v, template_name)) rescue nil}.compact[0]
		  if tmpl
		  	tmpl.render(object, locals_hash)
		  else
			  App.logger.info "RW AppClassMethods.render_template found no templates to render" 
			  nil
			end
		end

	end # AppClassMethods


	module UniversalHelpers
	#protected ... might need this for rails, but not for sinatra.
		
		def require_login
			App.logger.debug "RW UniversalHelpers...  #{self}#require_login with #{rack_warden}, and #{warden}"
			#logged_in? || warden.authenticate!
			warden.authenticated? || warden.authenticate!
	  end
	
		def warden
	    request.env['warden']
		end
		
		def warden_options
	    request.env['warden.options']
		end
	
		def current_user
	    #warden.authenticated? && warden.user
	    logged_in? && warden.user
		end
	
		def logged_in?
			App.logger.debug "RW UniversalHelpers#logged_in? #{warden.authenticated?}"
	    warden.authenticated? || warden.authenticate(:remember_me)
		end
		
		def authorized?(options=request)
			App.logger.debug "RW UniversalHelpers#authorized? user '#{current_user}'"
			current_user && current_user.authorized?(options) || request.script_name[/login|new|create|logout/]
		end

		def require_authorization(authenticate_on_fail=false, options=request)
			App.logger.debug "RW UniversalHelpers#require_authorization"
			logged_in? || warden.authenticate!
			unless authorized?(options)
				if authenticate_on_fail
					flash[:rw_error] = ("Please login to continiue")
					redirect url_for("/login")
				else
					flash[:rw_error] = ("You are not authorized to do that")
					redirect back
				end
			end		
		end

		# Returns the current rack_warden app instance stored in env.
	  def rack_warden
	  	App.logger.debug "RW UniversalHelpers.rack_warden #{request.env['rack_warden_instance']}"
	  	request.env['rack_warden_instance'] #.tap {|rw| rw.request = request}    #request}
	  end
	  
	  def account_widget
	  	rack_warden.erb :'rw_account_widget.html', :layout=>false
	  end
	  
	  def flash_widget
			# App.logger.debug "RW UniversalHelpers#flash_widget self.flash #{self.flash}"
			# App.logger.debug "RW UniversalHelpers#flash_widget rack.flash #{env['x-rack.flash']}"
			# App.logger.debug "RW UniversalHelpers#flash_widget.rack_warden.flash #{rack_warden.request.env['x-rack.flash']}"
	  	rack_warden.erb :'rw_flash_widget.html', :layout=>false
	  end
	
	end # UniversalHelpers




	# Also bring these into your main app helpers.
	module RackWardenHelpers

		# Access main logger from app instance.
		def logger
			settings.logger
		end
	
	  # WBR - override. This passes block to be rendered to first template that matches.
		def find_template(views, name, engine, &block)
			logger.debug "RW RackWardenHelpers#find_template name: #{name}, engine: #{engine}, block: #{block}, views: #{views}"
	    Array(views).each { |v| super(v, name, engine, &block) }
	  end
	  
	  # Because accessing app instance thru env seems to loose flash access.
	  def flash
	  	request.env['x-rack.flash']
	  end
		
	  def valid_user_input?
	    params['user'] && params['user']['email'] && params['user']['password']
	  end

		def rw_prefix(_route='')
			settings.rw_prefix.to_s + _route.to_s
		end
		
		def url_for(_url, _full_uri=false)
			url(rw_prefix(_url), _full_uri)
		end
		
		
	
		def verify_recaptcha(skip_redirect=false, ip=request.ip, response=params['g-recaptcha-response'])
			secret = settings.recaptcha[:secret]
	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=#{secret}&response=#{response}&remoteip=#{ip}").read)
	    logger.warn "RW RackWardenHelpers#verify_recaptcha #{_recaptcha.inspect}"
	    unless _recaptcha['success']
	    	flash.rw_error = "Please confirm you are human"
	    	redirect back unless skip_redirect
	    	Halt "You appear to be a robot."
	    end
	  end
	
	  def default_page
			nested_erb :'rw_index.html', :'rw_layout_admin.html', settings.layout
	  end
		
	  def nested_erb(*list)
	  	list.inject do |tmplt, lay|
	  		erb tmplt, :layout=>lay
	  	end
	  end
	  
	  def return_to(fallback=settings.default_route)
	  	redirect session[:return_to] || url_for(fallback)
	  end
	  
	  def redirect_error(message="Error")
	  	flash.rw_error = message
			redirect url_for("/error")
	  end
	  
	  def account_bar
	  	return unless current_user
	  	"<b>#{current_user.username rescue ('no username for current user: ' + current_user.inspect.to_s)}</b>"
	  end

	end # RackWardenHelpers

end # RackWarden