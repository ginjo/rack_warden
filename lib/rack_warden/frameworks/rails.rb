module RackWarden
  module Frameworks
    module Rails
      extend Base

      def selector
        parent_app_instance.class.parents.find{|x| x.to_s=='ActionDispatch'}
      end
      
      def views_path
        File.join(Dir.pwd, "app/views")
      end
      
      def setup_framework
    		ApplicationController.send(:include, RackWardenHelpers)
	
    		parent_app_class.instance_eval do
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

