module RackWarden
  module Frameworks
    module Sinatra
      
      extend Base
            
      def selector
        #puts "RW Sinatra.selector parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s=='Sinatra::Base'}
      end
      
      def views_path
        [File.join(Dir.pwd, "views/rack_warden"), File.join(Dir.pwd,"views")]
      end
      
      def setup_framework
        #puts "RW setup_framework for sinatra"
  			parent_app.helpers(RackWarden::UniversalHelpers)
  			  			
        # Define class method 'require_login' on framework controller.
				parent_app.define_singleton_method :require_login do |accept_conditions=/.*/, reject_conditions=false|
					before(accept_conditions){require_login unless reject_conditions}
				end
				
				# Add require_login to before filter of sinatra app.
  			parent_app.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden