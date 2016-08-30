module RackWarden
	# Also bring these into your main app helpers. What?
	module RackWardenHelpers

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

		def rw_prefix(_route='')
			settings.rw_prefix.to_s + _route.to_s
		end
		
		def url_for(_url, _full_uri=false)
			url(rw_prefix(_url), _full_uri)
		end
			
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