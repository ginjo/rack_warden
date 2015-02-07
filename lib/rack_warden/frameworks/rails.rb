module RackWarden
  module Frameworks
    module Rails
      
      extend Frameworks

      def selector
        App.logger.debug "RW Frameworks::Rails.selector" # parent_app.ancestors #{parent_app.ancestors}
        parent_app.ancestors.find{|x| x.to_s[/Rails|ActionDispatch/]} or defined?(::Rails)
      end
      
      def views_path
        [File.join(Dir.pwd, "app/views/rack_warden"), File.join(Dir.pwd, "app/views")]
      end
      

      module ClassMethods
				def require_login(*args)
					App.logger.debug "RW Frameworks::Rails::ClassMethods #{self}.require_login(#{args.inspect})"
					#before_filter(*[:require_login, args].flatten.compact)
					before_filter(*args) do |controller|
						controller.send :require_login
					end
				end
      end


      def setup_framework
        App.logger.debug "RW Frameworks::Rails.setup_framework"
    		ActionController::Base.send(:include, RackWarden::UniversalHelpers)
    		ActionController::Base.send(:protected, *RackWarden::UniversalHelpers.instance_methods)

    		ActionController::Base.helper_method UniversalHelpers.instance_methods
    			      
	      # Define class method 'require_login' on framework controller.
	      # Note that rails before-filters are also class methods, thus the need to differentiate method names (is this correct?).
	      App.logger.info "RW Frameworks::Rails.setup_framework ActionController::Base.extend ClassMethods"
				# ActionController::Base.define_singleton_method :require_login do |*args|
				# 	conditions_hash = args[0] || Hash.new
				# 	before_filter(:require_login, conditions_hash)
				# end
				ActionController::Base.extend ClassMethods
				
    		# The way you pass arguments here is fragile. If it's not correct, it will bomb with "undefined method 'before'...".
    		(ActionController::Base.require_login(RackWarden::App.require_login || {})) if RackWarden::App.require_login != false
      end
            
    end
  end
end

