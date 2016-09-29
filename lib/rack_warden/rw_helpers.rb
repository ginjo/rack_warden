module RackWarden
	# Also bring these into your main app helpers. What?
	module RackWardenHelpers
	
		def require_login(*args)
			logger.debug "RW Helpers...  #{self}#require_login with #{rack_warden}, and #{warden}, with args #{args}"
			#logged_in? || warden.authenticate!
			#warden.authenticated? || warden.authenticate!
			warden.authenticate!(*args)
	  end
	
		def warden
	    request.env['warden']
		end
		
		def warden_options
	    request.env['warden.options']
		end
	
		def current_user(scope = :default)
		  @current_user ||= {}
		  @current_user[scope] ||= (
  	    logger.debug "RW helper current_user with args: #{scope}"
  	    rslt = warden.user(scope)
  	    logger.debug "RW helper current_user retrieved: #{rslt}"
  	    rslt
	    )
		end
		
		def current_identity(scope = :default)
		  @current_identity ||= {}
		  @current_identity[scope] ||= (
  		  logger.debug "RW Getting current_identity with warden.session['identity']:  #{session['warden.user.default.session']}"
  		  if logged_in?(scope) && warden.session(scope)['identity']  #session['identity']
    		  identity = Identity.by_id(warden.session(scope)['identity'].to_s) rescue "RW UniversalHelpers.current_identity ERROR: #{$!}"
    		  logger.debug "RW retrieved current_identity #{identity.guid}"
    		  identity
  		  end
		  )
		rescue
		  logger.info "RW current_identity error: #{$!}"
		  nil
		end
	
		def logged_in?(scope=:default)
			#logger.debug "RW helpers logged_in? args: #{scope}"
	    rslt = warden.authenticated?(scope) || (settings.allow_remember_me && warden.authenticate(:remember_me))
	    #logger.debug "RW helpers logged_in? result: #{rslt}"
	    rslt
		end
		
		def authorized?(options=request)
			logger.debug "RW UniversalHelpers#authorized? user '#{current_user}'"
			logged_in? && current_user.authorized?(options) || request.script_name[/login|new|create|logout/]
		end

		def require_authorization(authenticate_on_fail=false, options=request)
			logger.debug "RW UniversalHelpers#require_authorization"
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
	  	logger.debug "RW UniversalHelpers.rack_warden #{request.env['rack_warden_instance']}"
	  	#request.env['rack_warden_instance'] #.tap {|rw| rw.request = request}    #request}
	  	request.env.rack_warden
	  end
	  
	  def account_widget
	  	rack_warden.erb :'rw_account_widget.html', :layout=>false
	  end
	  
	  def flash_widget
			# logger.debug "RW UniversalHelpers#flash_widget self.flash #{self.flash}"
			# logger.debug "RW UniversalHelpers#flash_widget rack.flash #{env['x-rack.flash']}"
			# logger.debug "RW UniversalHelpers#flash_widget.rack_warden.flash #{rack_warden.request.env['x-rack.flash']}"
	  	rack_warden.erb :'rw_flash_widget.html', :layout=>false
	  end

		# Access main logger from app instance.
		def logger
			settings.logger
		end
	
	  # WBR - override. This passes block to be rendered to first template that matches.
		def find_template(views, name, engine, &block)
			logger.debug "RW RackWardenHelpers#find_template name: #{name}, engine: #{engine}, block: #{block}, views: #{views}"
			logger.debug "RW RackWardenHelpers#find_template self: #{self}, self.class: #{self.class}, settings: #{settings}, current app layout: #{settings.layout}"
	    Array(views).each { |v| super(v, name, engine, &block) }
	  end
	  
	  # Because accessing app instance thru env seems to loose flash access.
	  def flash
	  	request.env['x-rack.flash']
	  end
		
	  def valid_user_input?
	    params['user'] && params['user']['email'] && params['user']['password']
	  end

		def rw_prefix(_extra_route='')
			settings.rw_prefix.to_s + _extra_route.to_s
		end
		
		def omniauth_prefix(_extra_route='')
			settings.omniauth_prefix.to_s + _extra_route.to_s
		end
		
		# Generate partial or full URL, including base-uri-prefix-whatever, and namespace,
		# with params hash, if exists.
    # args[0] (optional): symbol=namespace
    # args[1]: string=path
    # args[2]: truth=give-full-uri
    # options: hash=params
		def url_for(*args)
		  _params = args.last.is_a?(Hash) ? args.pop : Hash.new
		  _namespace_sym = args[0].is_a?(Symbol) ? args.shift : :rw
		  _namespace = case _namespace_sym
  		  when :rw; rw_prefix;
  		  when :omniauth; omniauth_prefix;
  		  else rw_prefix
		  end 
		  _path = args[0] || false
		  _give_full_uri = args[1] || false

		  #logger.debug "RW RackWardenHelpers#url_for _url: #{_url}, _full_uri: #{_full_uri.to_s}, _params: #{_params.__to_params__}"
			url(File.join(_namespace.to_s, _path.to_s), _give_full_uri).to_s +
			(_params.empty? ? '' : "?#{_params.__to_params__}")
		end
		
    # 	# Generate partial or full URL, including base-uri-prefix-whatever,
    # 	# with params hash, if exists.
    # 	# Arg 2 is _full_uri true or false, default false.
    # 	def url_for(_url, *args)
    # 	  _params = args.last.is_a?(Hash) ? args.pop : Hash.new
    # 	  _full_uri = args[0] || false
    # 	  _namespace = case args[1]
    # 	  when :rw; rw_prefix(_url);
    # 	  when :omni; omniauth_prefix;
    # 	  else rw_prefix(_url)
    # 	  end 
    # 	  #logger.debug "RW RackWardenHelpers#url_for _url: #{_url}, _full_uri: #{_full_uri.to_s}, _params: #{_params.__to_params__}"
    # 		url(rw_prefix(_url), _full_uri).to_s +
    # 		(_params.empty? ? '' : "?#{_params.__to_params__}")
    # 	end
			
		def verify_recaptcha(skip_redirect=false, ip=request.ip, response=params['g-recaptcha-response'])
			secret = settings.recaptcha[:secret]
	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=#{secret}&response=#{response}&remoteip=#{ip}").read)
	    logger.info "RW RackWardenHelpers#verify_recaptcha #{_recaptcha.inspect}"
	    unless _recaptcha['success']
	    	flash.rw_error = "Please confirm you are human"
	    	redirect back unless skip_redirect
	    	Halt "You appear to be a robot."
	    end
	  end
	
    # TODO: take the param from settings (create a setting for rw_index).
	  def default_page
			#nested_erb :'rw_index.html', :'rw_layout.html', settings.layout
			respond_with :rw_index
	  end
		
	  def nested_erb(*list)
	  	list.inject do |tmplt, lay|
	  		erb tmplt, :layout=>lay
	  	end
	  end
	  
	  # Redirect to session[:return_to] or the provided fallback.
	  def return_to(fallback=settings.default_route)
      # This use to use url_for(fallback), but namespaced actions would return_to to bogus places.
	  	redirect session[:return_to] || fallback
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