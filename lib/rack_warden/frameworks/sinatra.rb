module RackWarden
  module Frameworks
    module Sinatra
      
      extend Base
            
      def selector
        App.logger.debug "RW Sinatra.selector parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s=='Sinatra::Base'}
      end
      
      def views_path
        [File.join(Dir.pwd, "views/rack_warden"), File.join(Dir.pwd,"views")]
      end
      
      module ClassMethods
				def require_login(*args)
					App.logger.debug "RW class.require_login self #{self}, args #{args}"
					before(*args) do
						require_login
					end
				end
      end
      
      def setup_framework
        App.logger.debug "RW setup_framework for sinatra app #{parent_app}"
  			parent_app.helpers(RackWarden::UniversalHelpers)
        App.logger.info "RW registering class methods with #{parent_app}"
  			parent_app.register ClassMethods
  			parent_app.require_login(RackWarden::App.require_login) if RackWarden::App.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden