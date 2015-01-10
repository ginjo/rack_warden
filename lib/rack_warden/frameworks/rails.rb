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
    		ActionController::Base.send(:include, RackWarden::UniversalHelpers)
    			      
	      # Define class method 'require_login' on framework controller.
    		#parent_app_class.instance_eval do
    		# Probably more reliable to use this.
    		ActionController::Base.instance_eval do
    			puts "RW installing require_login into #{self}"
    		  def self.require_login(*args)
	    		  puts "RW class #{self}.require_login #{args}"
    		    before_filter(:require_login, *args)
    		  end
    	  end
    		# The way you pass arguments here is fragile. If it's not correct, it will bomb with "undefined method 'before'".
    		(ActionController::Base.require_login (rack_warden_app_class.require_login || {})) if rack_warden_app_class.require_login != false
      end
            
    end
  end
end

