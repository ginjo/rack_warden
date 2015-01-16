module RackWarden

	module UniversalHelpers
	protected
		
		def require_login
			App.logger.debug "RW instance #{self}.require_login with rack_warden: #{rack_warden}, and warden: #{warden}"
			#App.logger.debug "RW instance #{self}.require_login ancestors #{self.class.ancestors.inspect}"
			logged_in? || warden.authenticate!
	  end
	
		def warden
	    request.env['warden']
		end
	
		def current_user
	    warden.authenticated? && warden.user
		end
	
		def logged_in?
			App.logger.debug "RW logged_in? #{warden.authenticated?}"
	    warden.authenticated?
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
					redirect "/auth/login"
				else
					flash[:rw_error] = ("You are not authorized to do that")
					redirect back
				end
			end		
		end

		# Returns the current rack_warden app instance stored in env.
	  def rack_warden
	  	App.logger.debug "RW rack_warden method self #{request.env['rack_warden_instance']}"
	  	request.env['rack_warden_instance'].tap {|rw| rw.request = request}
	  end
	  
	  def account_widget
	  	rack_warden.erb :'rw_account_widget.html'
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
			App.logger.debug "RW find_template views: #{views}"
			App.logger.debug "RW find_template name: #{name}"
			App.logger.debug "RW find_template engine: #{engine}"
			App.logger.debug "RW find_template block: #{block}"
	    Array(views).each { |v| super(v, name, engine, &block) }
	  end
	
	
	  # TODO: Shouldn't these be in warden block above? But they don't work there for some reason.
	
	  def valid_user_input?
	    params['user'] && params['user']['email'] && params['user']['password']
	  end
	
		def verify_recaptcha(skip_redirect=false, ip=request.ip, response=params['g-recaptcha-response'])
			secret = settings.recaptcha[:secret]
	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=#{secret}&response=#{response}&remoteip=#{ip}").read)
	    App.logger.warn "RW recaptcha #{_recaptcha.inspect}"
	    unless _recaptcha['success']
	    	flash.rw_error = "Please confirm you are human"
	    	redirect back unless skip_redirect
	    	Halt "You appear to be a robot."
	    end
	  end
	
	  def default_page
			nested_erb :'rw_index.html', :'rw_layout_admin.html', settings.layout    #settings.layout
	  end
		
	  def nested_erb(*list)
	  	template = list.shift
	  	counter =0
	  	list.inject(template) do |tmplt, lay|
	  		#puts "RW LAYOUTS lay: #{lay}, rslt: #{tmplt}"
	  		erb tmplt, :layout=>lay
	  	end
	  end
	  
	  def return_to(fallback=settings.default_route)
	  	redirect session[:return_to] || url(fallback, false)
	  end
	  
	  def account_bar
	  	return unless current_user
	  	"<b>#{current_user.username}</b>"
	  end

	end # RackWardenHelpers

end # RackWarden