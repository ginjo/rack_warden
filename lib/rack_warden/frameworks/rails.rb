module RackWarden
  module Frameworks
    module Rails
      
      extend Base

      def selector
        puts "RAILS.selector"
        parent_app_class.parents.find{|x| x.to_s=='ActionDispatch'}
      end
      
      def views_path
        File.join(Dir.pwd, "app/views")
      end
      
      def setup_framework
        puts "RAILS.setup_framework parent_app_class #{parent_app_class}"
    		ApplicationController.send(:include, RackWarden::App::RackWardenHelpers)
    		
    		RackWarden::App.set :database_config, get_database_config
	      
	      # Define class method 'require_login' on framework controller.
    		#parent_app_class.instance_eval do        #This seems to work too.
    		ApplicationController.instance_eval do
    		  def self.require_login(*args)
    		    before_filter(:require_login, *args) do
    		      require_login
    		    end
    		  end
    	  end
    		(ApplicationController.before_filter :require_login, *Array(rack_warden_app_class.require_login).flatten) if rack_warden_app_class.require_login != false
      end
            
    end
  end
end

