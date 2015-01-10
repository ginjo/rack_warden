module RackWarden

	module UniversalHelpers

		def require_login
			puts "RW #{self}.require_login"
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
	  	#puts "rack_warden method self #{request.env['rack_warden']}"
	  	request.env['rack_warden_instance']
	  end
	
	end

	# Also bring these into your main app helpers.
	module RackWardenHelpers
	  # WBR - override. This passes block to be rendered to first template that matches.
		def find_template(views, name, engine, &block)
			# puts "THE VIEWS: #{views}"
			# puts "THE NAME: #{name}"
			# puts "THE ENGINE: #{engine}"
			# puts "THE BLOCK: #{block}"
	    Array(views).each { |v| super(v, name, engine, &block) }
	  end
	
	
	  # TODO: Shouldn't these be in warden block above? But they don't work there for some reason.
	
	  def valid_user_input?
	    params['user'] && params['user']['email'] && params['user']['password']
	  end
	
		def verify_recaptcha(skip_redirect=false, ip=request.ip, response=params['g-recaptcha-response'])
			secret = settings.recaptcha[:secret]
	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=#{secret}&response=#{response}&remoteip=#{ip}").read)
	    puts "RECAPTCHA", _recaptcha
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