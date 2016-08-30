module RackWarden
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
		
		def current_identity
		  App.logger.debug "RW Getting current_identity for identity id:  #{session['identity']}"
		  if session['identity']
  		  identity = IdentityRepo.by_id(session['identity'].to_s) rescue "RW UniversalHelpers.current_identity ERROR: #{$!}"
  		  App.logger.debug "RW retrieved current_identity #{identity}"
  		  identity
		  end
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
end