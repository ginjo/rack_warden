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
				ActionController::Base.define_singleton_method :require_login do |conditions_hash={}|
					before_filter(:require_login, conditions_hash)
				end
				
    		# The way you pass arguments here is fragile. If it's not correct, it will bomb with "undefined method 'before'...".
    		(ActionController::Base.require_login (rack_warden_app_class.require_login || {})) if rack_warden_app_class.require_login != false
      end
            
    end
  end
end

