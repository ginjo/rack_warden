module RackWarden
  module Frameworks
    module Base
      
      def select_framework(*args)
        puts "BASE.select_framework args: #{args}"
        @selector.call(*args) && self #&& args.last[:rack_warden_app_class].include(self, *args)
      end
      
      def views_path
        @views_path.call
      end
    	
      # def self.included(base, *args)
      #   base.setup_framework(*args)
      # end
    	
    end
  end
end