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
      
      def setup_framework
        App.logger.debug "RW setup_framework for sinatra app #{parent_app}"
  			parent_app.helpers(RackWarden::UniversalHelpers)
  			  			
        # Define class method 'require_login' on framework controller.
        # TODO: I don't think the reject_conditions will work,
        # unless you find a way to pass in the URI to the before block,
        # and test the regexp against that.
        App.logger.info "RW defining 'require_login(accept_conditions-regexp, reject_conditions-regexp)' on #{parent_app}"
				parent_app.define_singleton_method :require_login do |*args|
					accept_conditions = args[0] || (/.*/)
					reject_conditions = args[1] || false
					before(accept_conditions){require_login unless reject_conditions}
				end
				
				# Add require_login to before filter of sinatra app.
  			parent_app.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden