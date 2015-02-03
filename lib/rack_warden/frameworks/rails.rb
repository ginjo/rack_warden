module RackWarden
  module Frameworks
    module Rails
      
      extend Frameworks

      def selector
        App.logger.debug "RW Rails.selector parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s[/Rails|ActionDispatch/]} or defined?(::Rails)
      end
      
      def views_path
        [File.join(Dir.pwd, "app/views/rack_warden"), File.join(Dir.pwd, "app/views")]
      end
      
      def setup_framework
        App.logger.debug "RW setup_framework for rails"
    		ActionController::Base.send(:include, RackWarden::UniversalHelpers)
    		ActionController::Base.helper_method UniversalHelpers.instance_methods
    			      
	      # Define class method 'require_login' on framework controller.
	      # Note that rails before-filters are also class methods, thus the need to differentiate method names (is this correct?).
	      App.logger.info "RW defining 'require_login(conditions-hash)' on ActionController::Base"
				ActionController::Base.define_singleton_method :require_login do |*args|
					conditions_hash = args[0] || Hash.new
					before_filter(:require_login, conditions_hash)
				end
				
    		# The way you pass arguments here is fragile. If it's not correct, it will bomb with "undefined method 'before'...".
    		(ActionController::Base.require_login(rack_warden_app_class.require_login || {})) if rack_warden_app_class.require_login != false
      end
            
    end
  end
end

