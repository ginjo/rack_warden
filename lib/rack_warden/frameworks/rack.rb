module RackWarden
  module Frameworks
    module Rack
      
      extend Frameworks
            
      def selector
        App.logger.debug "RW Frameworks::Rack.selector" # "parent_app.ancestors #{parent_app.ancestors}"
        parent_app.ancestors.find{|x| x.to_s=='Rack::URLMap'}
      end
      
      def views_path
        [File.join(Dir.pwd, "views/rack_warden"), File.join(Dir.pwd,"views")]
      end
      
      module ClassMethods
				# def require_login(*args)
				# 	App.logger.debug "RW class.require_login self #{self}, args #{args}"
				# 	before(*args) do
				# 		require_login
				# 	end
				# end
      end
      
      def setup_framework
        App.logger.debug "RW Frameworks::Rack.setup_framework for rack app: #{parent_app}"
  			parent_app.include(RackWarden::UniversalHelpers)
        App.logger.debug "RW Frameworks::Rack.setup_framework registering class methods with: #{parent_app}"
  			parent_app.extend ClassMethods
  			# This seems to protect all rack routes, regardless of any other settings downstream.
  			App.set :rack_authentication, '.*'
  			#parent_app.require_login(RackWarden::App.require_login) if RackWarden::App.require_login != false
    	end
    	
    end # Rack
  end # Frameworks
end # RackWarden