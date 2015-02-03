module RackWarden
  module Frameworks

    # Module methods.
    class << self
    	attr_accessor :selected_framework
    	
      # Select the framework of the parent app.
      def select_framework(env)
        App.logger.debug "RW framework constants: #{Frameworks.constants}"
        Frameworks.constants.dup.tap{|_constants| _constants.delete(:Base)}.each do |c|
          r = Frameworks.const_get(c).framework_selector(env) #rescue nil
          if r
          	Frameworks.selected_framework = r
          	App.logger.info "RW selected framework #{Frameworks.selected_framework}"
            return r
          end
        end
        nil
      end
      
      # Extend target with target (like saying 'extend self' within target).
      def extended(target)
        target.extend target
      end
    end
    

    ###  Methods extended into framework module  ###

    attr_accessor :parent_app_instance, :parent_app_class, :parent_app, :rack_warden_app_instance, :rack_warden_app_class

    # Sets framework module with variables from env (the scope of the parent app's initializer),
    # and runs the framework selector logic.
    # Returns the framework module or nil.
    def framework_selector(app)
    	App.logger.debug "RW framework_selector #{self}"
      @parent_app_instance = app #env.eval 'parent_app_instance'
      @parent_app_class = @parent_app_instance.class
      @parent_app = @parent_app_instance.is_a?(Class) ? @parent_app_instance : @parent_app_class
      selector && self
    end

    ###  End methods extended into framework module  ###
  	
  end
end