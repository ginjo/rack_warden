module RackWarden

	module UniversalHelpers
	protected
		
		def require_login
			App.logger.debug "RW instance #{self}.require_login with rack_warden: #{rack_warden}, and warden: #{warden}"
			#App.logger.debug "RW instance #{self}.require_login ancestors #{self.class.ancestors.inspect}"
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
			App.logger.debug "RW logged_in? #{warden.authenticated?}"
	    warden.authenticated? || warden.authenticate(:remember_me)
		end
		
		def authorized?(options=request)
			App.logger.debug "RW authorized? user '#{current_user}'"
			current_user && current_user.authorized?(options) || request.script_name[/login|new|create|logout/]
		end

		def require_authorization(authenticate_on_fail=false, options=request)
			App.logger.debug "RW require_authorization"
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
	  	App.logger.debug "RW rack_warden helper method self #{self}"
	  	App.logger.debug "RW rack_warden helper method request.env['rack_warden_instance'] #{request.env['rack_warden_instance']}"
	  	request.env['rack_warden_instance'] #.tap {|rw| rw.request = request}    #request}
	  end
	  
	  def account_widget
	  	rack_warden.erb :'rw_account_widget.html', :layout=>false
	  end
	  
	  def flash_widget
	  	#return "flash_widget DISABLED"
	  	App.logger.debug "RW flash_widget self.flash #{self.flash}"
	  	App.logger.debug "RW flash_widget rack.flash #{env['x-rack.flash']}"
	  	App.logger.debug "RW flash_widget.rack_warden.flash #{rack_warden.request.env['x-rack.flash']}"
	  	#rack_warden.settings.render_template :'rw_flash_widget.html'
	  	#"FLASH WIDGET DISABLED"
	  	#flash.rw_test
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
			logger.debug "RW find_template name: #{name}, engine: #{engine}, block: #{block}, views: #{views}"
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
	    logger.warn "RW recaptcha #{_recaptcha.inspect}"
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
	  	"<b>#{current_user.username}</b>"
	  end

	end # RackWardenHelpers

end # RackWarden