module RackWarden
  module Frameworks
    module Rails
      
      extend Base

      def selector
        puts "RW Rails.selector parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s[/Rails|ActionDispatch/]}     #{|x| x.to_s=='ActionDispatch'}
      end
      
      def views_path
        [File.join(Dir.pwd, "app/views/rack_warden"), File.join(Dir.pwd, "app/views")]
      end
      
      def setup_framework
        puts "RW Rails.setup_framework parent_app #{parent_app}"
    		ApplicationController.send(:include, RackWarden::App::RackWardenHelpers)
    			      
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

