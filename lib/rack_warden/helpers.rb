module RackWarden

	module UniversalHelpers
	protected
		
		def require_login
			App.logger.debug "RW instance #{self}.require_login with rack_warden: #{rack_warden}, and warden: #{warden}"
			warden.authenticate!
	  end
	
		def warden
	    request.env['warden']
		end
	
		def current_user
	    warden.user
		end
	
		def logged_in?
	    warden.authenticated?
		end
		
		def authorized?(authenticate_on_fail=false)
			unless current_user.authorized?(request)
				if authenticate_on_fail
					flash(:rwarden)[:error] = ("Please login to continiue")
					redirect "/auth/login"
				else
					flash(:rwarden)[:error] = ("You are not authorized to do that")
					redirect back
				end
			end
		end

		# Returns the current rack_warden app instance stored in env.
	  def rack_warden
	  	App.logger.debug "rack_warden method self #{request.env['rack_warden']}"
	  	request.env['rack_warden_instance']
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
	    App.logger.info "RW recaptcha", _recaptcha
	    unless _recaptcha['success']
	    	flash(:rwarden)[:error] = "Please confirm you are human"
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