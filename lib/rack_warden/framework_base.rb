module RackWarden
  module Frameworks
    module Base
      
      # Module methods to be called on Base from RackWarden::App (and instance).
      class << self
        # Select the framework of the parent app.
        def select_framework(env)
          puts "FRAMEWORK CONSTANTS: #{Frameworks.constants}"
          Frameworks.constants.each do |c|
            r = Frameworks.const_get(c).framework_selector(env) rescue nil
            return r if r
          end
        end
      end
      

      ###  Methods extended into framework module  ###

      attr_accessor :parent_app_instance, :parent_app_class, :rack_warden_app_instance, :rack_warden_app_class

      # Sets framework module with variables from env (the scope of the parent app's initializer),
      # and runs the framework selector logic.
      # Returns the framework module or nil.
      def framework_selector(env)
        puts "BASE.select_framework env: #{env.eval 'self'} locals: #{env.eval 'local_variables'}"
        @initialization_args = env.eval 'initialization_args'
        @parent_app_instance = env.eval 'parent_app_instance'
        @parent_app_class = @parent_app_instance.class
        @rack_warden_app_instance = env.eval 'self'
        @rack_warden_app_class = @rack_warden_app_instance.class
        selector && self
      end

      ###  End methods extended into framework module  ###
    	
    end
  end
end