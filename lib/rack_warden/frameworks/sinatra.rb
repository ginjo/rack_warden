require 'rack_warden/framework_base'
module RackWarden
  module Frameworks
    module Sinatra
      extend Base
      
      @selector = lambda {|*args| args.last[:parent_app_instance].class.ancestors.find{|x| x.to_s=='Sinatra::Base'}}
      
      @views_path = lambda {File.join(Dir.pwd,"views")}
      
      def setup_framework(parent_app_instance, args, opts)
    		puts "RACKWARDEN initializing parent sinatra framework: #{[parent_app_instance, args, opts]}"
    		puts "SELF in setup_framework: #{self}"

    		rack_warden_app_class = self.class
  			parent_app_instance.class.helpers(RackWarden::App::RackWardenHelpers)
  			default_parent_views = File.join(Dir.pwd,"views")

        # TODO: Move some of this to Frameworks::Base
  			parent_app_instance.class.instance_eval do
  			  def self.require_login(*args)
    			  #options = args.last.is_a?(Hash) ? args.pop : Hash.new
  			    before(*args) do
  			      require_login
  			    end
  			  end
			  end
  			parent_app_instance.class.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
    	end
    	
    end
  end
end