module RackWarden
  module Frameworks
    module Sinatra
      
      extend Base
            
      def selector
        puts "SINATRA.selector"
        parent_app_class.ancestors.find{|x| x.to_s=='Sinatra::Base'}
      end
      
      def views_path
        File.join(Dir.pwd,"views")
      end
      
      def setup_framework
        puts "SINATRA.setup_framework parent_app_class #{parent_app_class}"
  			parent_app_class.helpers(RackWarden::App::RackWardenHelpers)
  			
  			RackWarden::App.set :database_config, get_database_config
  			
        # Define class method 'require_login' on framework controller.
  			parent_app_class.instance_eval do
  			  def self.require_login(*args)
  			    before(*args) do
  			      require_login
  			    end
  			  end
			  end
  			parent_app_class.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
    	end
    	
    end # Sinatra
  end # Frameworks
end # RackWarden