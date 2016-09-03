module RackWarden
  module Frameworks
    module Rack

      module ClassMethods
				# def require_login(*args)
				# 	App.logger.debug "RW class.require_login self #{self}, args #{args}"
				# 	before(*args) do
				# 		require_login
				# 	end
				# end
      end
      
      def self.included(base)
        base.include FrameworkHelpers
        base.extend ClassMethods
        ###RackWarden::App.set :rack_authentication, '.*'
      end
    	
    end # Rack
  end # Frameworks
end # RackWarden