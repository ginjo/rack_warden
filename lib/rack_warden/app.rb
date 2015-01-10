# require 'bundler'
# Bundler.require

module RackWarden
  class App < Sinatra::Base
        
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :database_config => nil  #, "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :database_default => "sqlite3::memory:"   #"sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    
    # Load config from file, if any exist.
    Hash.new.tap do |hash|
      config_files.each {|c| hash.merge!(YAML.load_file(File.join(Dir.pwd, c))) rescue nil}
      set hash
    end
    
    
    
    enable :sessions
    register Sinatra::Flash
    
		begin
	    enable :logging
	    set :log_file, File.new(settings.log_path, 'a+')
	    settings.log_file.sync = true
	    use Rack::CommonLogger, settings.log_file
	  rescue
	  end
	  
		include RackWarden::WardenConfig
		include RackWarden::Routes
		
    helpers RackWardenHelpers
    helpers UniversalHelpers
  
  
  
    # WBR - This will receive params and a block from the parent "use" statement.
    # This middleware app has been modified to process the parent use-block in
    # the context of the RackWarden class. So you can set settings on RackWarden,
    # when you call "use RackWarden"
    # Example:
    #
    # use RackWarden :layout=>:'my_layout' do |rack_warden_instance, app|
  	# 	set :myvar, 'something'
  	#	end
  	#
  	def initialize(parent_app_instance=nil, *args, &block)
  		super(parent_app_instance, &Proc.new{}) # Must send empty proc, not original proc, since we're calling original block here.
  	  initialization_args = args.dup
  		puts "RW new instance with parent: #{@app}"
  		# extract options.
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		#settings = self.class
  		if app && !settings.initialized
  		  puts "RW initializing settings"
  		  
  			# Save original views from opts.
  			#settings.set(:original_views, opts.has_key?(:views) ? settings.views : nil)
  			settings.set(:original_views, settings.views)

  			# Set app settings with remainder of opts.
  			settings.set opts if opts.any?
  			
  			# Eval the use-block from the parent app, in context of this app.
  			settings.instance_exec(self, app, &block) if block_given?
  			
  			# Do framework setup.
  			framework_module = Frameworks::Base.select_framework(binding)
    		puts "RW selected framework module #{framework_module}"
    		if framework_module
      		framework_module.setup_framework
        
          # Manipulate views
      		new_views = []
      		new_views.unshift settings.original_views
      		new_views.unshift framework_module.views_path unless settings.views==false
      		new_views.unshift settings.views
      		settings.set :views, new_views.flatten.compact.uniq
      		
      		puts "RW compiled views: #{settings.views.inspect}"
    		end
    		settings.set :initialized, true
  		end

  	end # initialize
  	
		# This might be breaking older rails installations.
		def call(env)  
			#puts "RW instance.app #{app}"
		  #puts "RW instance.call(env) #{env.to_yaml}"
		  env['rack_warden_instance'] = self
		  super(env)
		end 


  end # App 
end # RackWarden


