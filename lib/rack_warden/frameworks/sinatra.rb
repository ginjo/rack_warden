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
        # Define class method 'require_login' on Sinatra::Base subclass (the app).
        # TODO: I don't think the reject_conditions will work,
        # unless you find a way to pass in the URI to the before block,
        # and test the regexp against that.
				def require_login(*args)
					#accept_conditions = args[0] || (/.*/)
					#reject_conditions = args[1] || false
					#before(accept_conditions){puts "RW class.require_login self #{self}, conditions #{accept_conditions}, reject #{reject_conditions}"; require_login unless reject_conditions}
					before(*args){puts "RW class.require_login self #{self}, args #{args}"; require_login}
				end
      end
      
      def setup_framework
        App.logger.debug "RW setup_framework for sinatra app #{parent_app}"
  			parent_app.helpers(RackWarden::UniversalHelpers)
        App.logger.info "RW registering class methods with #{parent_app}"
  			parent_app.register ClassMethods
				# Add require_login to before filter of sinatra app.
  			parent_app.require_login(RackWarden::App.require_login) if RackWarden::App.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden