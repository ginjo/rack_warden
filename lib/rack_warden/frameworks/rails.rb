

def setup_framework(parent_app_instance, args, opts)
	puts "RACKWARDEN initializing parent app: #{parent_app_instance}"
	#puts "RACKWARDEN parent app parents: #{parent_app_instance.class.parents}"
	#puts "RACKWARDEN parent app ancestors: #{parent_app_instance.class.ancestors}"
	rack_warden_app_class = self.class
	case
	when parent_app_instance.class.ancestors.find{|x| x.to_s=='Sinatra::Base'}
		parent_app_instance.class.helpers(RackWardenHelpers)
		default_parent_views = File.join(Dir.pwd,"views")
		
		parent_app_instance.class.instance_eval do
		  def self.require_login(*args)
			  #options = args.last.is_a?(Hash) ? args.pop : Hash.new
		    before(*args) do
		      require_login
		    end
		  end
	  end
		parent_app_instance.class.require_login(rack_warden_app_class.require_login) if rack_warden_app_class.require_login != false
	when parent_app_instance.class.parents.find{|x| x.to_s=='ActionDispatch'}
		ApplicationController.send(:include, RackWardenHelpers)
		default_parent_views = File.join(Dir.pwd, "app/views")
		
		parent_app_instance.class.instance_eval do
		  def self.require_login(*args)
			  #options = args.last.is_a?(Hash) ? args.pop : Hash.new
		    before_filter(:require_login, *args) do
		      require_login
		    end
		  end
	  end
		(ApplicationController.before_filter :require_login, *Array(rack_warden_app_class.require_login).flatten) if rack_warden_app_class.require_login != false
	end

	new_views = []
	original_views = rack_warden_app_class.original_views
	# append parent rails views folder unless opts.has_key?(:views)
	new_views << default_parent_views unless opts.has_key?(:views)
	# append original_views, if original_views
	new_views << original_views if original_views
	rack_warden_app_class.set(:views => [Array(rack_warden_app_class.views), new_views].flatten.compact.uniq) if new_views.any?
	puts "RACKWARDEN views: #{rack_warden_app_class.views}"
end