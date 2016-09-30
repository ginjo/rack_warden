module RackWarden
  module Frameworks
    module Rails

      module ClassMethods
				def require_login(*args)
					App.logger.debug "RW Frameworks::Rails::ClassMethods #{self}.require_login(#{args.inspect})"
					#before_filter(*[:require_login, args].flatten.compact)
					unless args[0] == false
  					before_filter(*args) do |controller|
  						controller.send :require_login
  					end
  				end
				end
      end
      
      def self.included(base)
        base.include FrameworkHelpers
        base.send :protected, *FrameworkHelpers.instance_methods
        base.helper_method *FrameworkHelpers.instance_methods
        base.extend ClassMethods
        base.require_login(RackWarden::App.require_login || {})) if RackWarden::App.require_login != false
      end

    end
  end
end

