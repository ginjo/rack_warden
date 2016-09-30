module RackWarden
  module Frameworks
    module Sinatra
    
      module ClassMethods
				def require_login(*args)
					App.logger.debug "RW Frameworks::Sinatra.require_login self: #{self}, args: #{args.inspect}"
					unless args[0] == false
  					before(*args) do
  						require_login
  					end
  				end
				end
      end
      
      def self.included(base)
        base.helpers FrameworkHelpers
        base.register ClassMethods
        base.require_login(RackWarden::App.require_login) if RackWarden::App.require_login != false
      end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden