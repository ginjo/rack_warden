module RackWarden
	module Env
		
		def cookies
  		self['rack.cookies']
  	end
  	
  	def remember_token
  		cookies[rack_warden.settings.remember_token_cookie_name]
	  end

  	def remember_token=(string)
  		App.logger.debug "RW env.remember_token= #{string} (#{rack_warden.settings.remember_token_cookie_name})"
  		cookies[rack_warden.settings.remember_token_cookie_name]= string
	  end
	  
	  def rack_warden
  		self['rack_warden_instance']
	  end
	  
	  def rack_warden=(object)
	  	App.logger.debug "RW env['rack_warden_instance']=  #{object}"  #{object === Class ? object.name : object.class.name}"
  		self['rack_warden_instance'] = object
	  end
	  
	end
end