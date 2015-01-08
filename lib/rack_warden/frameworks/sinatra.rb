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
  			parent_app.helpers(RackWarden::App::RackWardenHelpers)
  			  			
        # Define class method 'require_login' on framework controller.
  			parent_app.instance_eval do
  			  def self.require_login(*args)
  			  	#puts "RW class #{self}.require_login #{args}"
  			    before(*args) do
	  			    #puts "RW instance #{self}.require_login #{request.path_info}"
  			      require_login
  			    end
  			  end
			  end
  			parent_app.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden