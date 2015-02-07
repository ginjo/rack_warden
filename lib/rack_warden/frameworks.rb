module RackWarden
  module Frameworks

    # Module methods.
    class << self
    	attr_accessor :selected_framework
    	
      # Select the framework of the parent app.
      def select_framework(env)
        App.logger.debug "RW Frameworks.select_framework constants: #{constants}"
        self.constants.dup.tap{|_constants| _constants.delete(:Base)}.each do |c|
          @selected_framework = self.const_get(c).framework_selector(env)
          break if @selected_framework
        end
        @selected_framework ||= Rack
      	App.logger.info "RW Frameworks.select_framework selected #{@selected_framework}"
        @selected_framework
      end
      
      # Extend target with target (like saying 'extend self' within target).
      def extended(target)
        target.extend target
      end
    
    end # class << self
    

    ###  Methods extended into framework module  ###

    attr_accessor :parent_app_instance, :parent_app_class, :parent_app

    # Sets framework module with variables from env (the scope of the parent app's initializer),
    # and runs the framework selector logic.
    # Returns the framework module or nil.
    def framework_selector(app)
    	App.logger.debug "RW Frameworks#framework_selector self: #{self}"
      @parent_app_instance = app #env.eval 'parent_app_instance'
      @parent_app_class = @parent_app_instance.class
      @parent_app = @parent_app_instance.is_a?(Class) ? @parent_app_instance : @parent_app_class
      selector && self
    end

    ###  End methods extended into framework module  ###
  	
  end
end