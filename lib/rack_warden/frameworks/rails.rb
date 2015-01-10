module RackWarden
  module Frameworks
    module Rails
      
      extend Base

      def selector
        #puts "RW Rails.selector parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s[/Rails|ActionDispatch/]} or defined?(Rails)
      end
      
      def views_path
        [File.join(Dir.pwd, "app/views/rack_warden"), File.join(Dir.pwd, "app/views")]
      end
      
      def setup_framework
        #puts "RW setup_framework for rails"
    		ApplicationController.send(:include, RackWarden::UniversalHelpers)
    			      
	      # Define class method 'require_login' on framework controller.
    		#parent_app_class.instance_eval do
    		# Probably more reliable to use this.
    		ApplicationController.instance_eval do
    			puts "RW installing require_login into #{self}"
    		  def self.require_login(*args)
	    		  puts "RW #{self}.require_login"
    		    before_filter(:require_login, *args) do
    		      require_login
    		    end
    		  end
    	  end
    		#(ApplicationController.before_filter :require_login, *Array(rack_warden_app_class.require_login).flatten) if rack_warden_app_class.require_login != false
    		(ApplicationController.require_login rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
      end
            
    end
  end
end

