# require 'bundler'
# Bundler.require

module RackWarden
  class App < Sinatra::Base
    enable :sessions
    register Sinatra::Flash
        
    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :database_config => nil  #, "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :database_default => "sqlite3::memory:"   #"sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :log_path, File.join(Dir.pwd, 'log', 'rack_warden.log')
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    
    # Load config from file, if any exist.
    Hash.new.tap do |hash|
      config_files.each {|c| puts File.join(Dir.pwd, c); hash.merge!(Psych.load_file(File.join(Dir.pwd, c))) rescue nil}
      set hash
    end
  
  
    # WBR - This will receive params and a block from the parent "use" statement.
    # This middleware app has been modified to process the parent use-block in
    # the context of the RackWarden class. So you can set settings on RackWarden,
    # when you call "use RackWarden::App"
    # Example:
    #
    # use RackWarden::App :layout=>:'my_layout' do |rack_warden_instance, parent_app_instance|
  	# 	set :myvar, 'something'
  	#	end
  	#
  	def initialize(parent_app_instance=nil, *args, &block)
  	  initialization_args = args.dup
  		puts "RW INITIALIZE middleware instance [parent_app_instance, self, args, block]: #{[parent_app_instance, self, args, block]}"
  		# extract options.
  		opts = args.last.is_a?(Hash) ? args.pop : {}
  		rack_warden_app_class = self.class
  		if parent_app_instance && !settings.initialized
  		  puts "RW has parent: #{parent_app_instance}"
  		  
  			# Save original views from opts.
  			#rack_warden_app_class.set(:original_views, opts.has_key?(:views) ? rack_warden_app_class.views : nil)
  			rack_warden_app_class.set(:original_views, rack_warden_app_class.views)

  			# Set app settings with remainder of opts.
  			rack_warden_app_class.set opts if opts.any?
  			
  			# Eval the use-block from the parent app, in context of this app.
  			rack_warden_app_class.instance_exec(self, parent_instance, &block) if block_given?
  			
  			# Do framework setup.
  			framework_module = Frameworks::Base.select_framework(binding)
    		puts "RW framework_module #{framework_module}"
    		if framework_module
      		framework_module.setup_framework
        
          # Manipulate views
      		new_views = []
      		#original_views = self.class.original_views
      		# append parent rails views folder unless opts.has_key?(:views)
      		#new_views << framework_module.views_path unless opts[:views]==false #opts.has_key?(:views)
      		# append original_views, if original_views
      		#new_views << original_views if original_views
      		#self.class.set(:views => [new_views, Array(self.class.views)].flatten.compact.uniq) if new_views.any?
      		
      		new_views.unshift rack_warden_app_class.original_views
      		new_views.unshift framework_module.views_path unless rack_warden_app_class.views==false
      		new_views.unshift rack_warden_app_class.views
      		rack_warden_app_class.set :views, new_views.flatten.compact.uniq
      		
      		puts "RW views: #{self.class.views}"
    		end
    		settings.set :initialized, true
  		end
  		# finally, send parent app to super, but don't send the use-block (thus the empty proc)
  		super(parent_app_instance, &Proc.new{})
  	end
  	
  	# For testing interception of request.
  	# This might be breaking older rails installations
		# if development?
		#   def call(env={})  
		#   	puts "RW instance.app #{app}"
		#     puts "RW instance.call(env) #{env.to_yaml}"
		#     super(env)
		#   end 
		# end
	
    use Warden::Manager do |config|
      # Tell Warden how to save our User info into a session.
      # Sessions can only take strings, not Ruby code, we'll store
      # the User's `id`
      config.serialize_into_session{|user| user.id }
      # Now tell Warden how to take what we've stored in the session
      # and get a User from that information.
      config.serialize_from_session{|id| User.get(id) }

      config.scope_defaults :default,
        # "strategies" is an array of named methods with which to
        # attempt authentication. We have to define this later.
        :strategies => [:password],
        # The action is a route to send the user to when
        # warden.authenticate! returns a false answer. We'll show
        # this route below.
        :action => 'auth/unauthenticated'
      # When a user tries to log in and cannot, this specifies the
      # app to send the user to.
      config.failure_app = self
    end

    Warden::Manager.before_failure do |env,opts|
      env['REQUEST_METHOD'] = 'POST'
    end

    Warden::Strategies.add(:password) do
      def valid?
        params['user'] && params['user']['username'] && params['user']['password']
      end

      def authenticate!
        user = User.first(['username = ? or email = ?', params['user']['username'], params['user']['username']])  #(username: params['user']['username'])

        if user.nil?
          fail!("The username you entered does not exist.")
        elsif user.authenticate(params['user']['password'])
          success!(user)
        else
          fail!("Could not log in")
        end
      end
    
    end
  
    # Also bring these into your main app helpers.
    module RackWardenHelpers
  	  # WBR - override. This passes block to be rendered to first template that matches.
  		def find_template(views, name, engine, &block)
  			# puts "THE VIEWS: #{views}"
  			# puts "THE NAME: #{name}"
  			# puts "THE ENGINE: #{engine}"
  			# puts "THE BLOCK: #{block}"
  	    Array(views).each { |v| super(v, name, engine, &block) }
  	  end
	  
  		def require_login
  			warden.authenticate!
  	  end
		
  		def warden
  	    request.env['warden']
  		end

  		def current_user
  	    warden.user
  		end
		
  		def logged_in?
  	    warden.authenticated?
  		end
		
		
  	  # TODO: Shouldn't these be in warden block above? But they don't work there for some reason.
	  
  	  def valid_user_input?
  	    params['user'] && params['user']['email'] && params['user']['password']
  	  end
	  
      # def create_user
      #     
      #   verify_recaptcha if settings.recaptcha[:secret]
      #     
      #   #return unless valid_user_input?
      #         
      #         @user = User.new(params['user'])
      #   @user.save #&& warden.set_user(@user)
      # end
		
   		def verify_recaptcha(skip_redirect=false, ip=request.ip, response=params['g-recaptcha-response'])
   		  secret = settings.recaptcha[:secret]
  	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=#{secret}&response=#{response}&remoteip=#{ip}").read)
  	    puts "RECAPTCHA", _recaptcha
  	    unless _recaptcha['success']
  	    	flash(:rwarden)[:error] = "Please confirm you are human"
  	    	redirect back unless skip_redirect
  	    	Halt "You appear to be a robot."
  	    end
  	  end
	  
  	  def default_page
  	  	erb :'rw_index.html', :layout=>settings.layout
  	  end
		
    end # RackWardenHelpers
    helpers RackWardenHelpers
  
  	if defined? ::RACK_WARDEN_STANDALONE
  		get '/?' do
  			default_page
  		end
  	end
	
    get '/auth/?' do
      default_page
    end

    get '/auth/login' do
      if User.count > 0
        erb :'rw_login.html', :layout=>settings.layout
      else
        flash(:rwarden)[:error] = warden.message || "Please create an admin account"
        redirect url('/auth/new', false)
      end
    end

    post '/auth/login' do
      warden.authenticate!

      flash(:rwarden)[:success] = warden.message || "Successful login"

  		puts "RETURN_TO #{session[:return_to]}"
      if session[:return_to].nil?
        redirect url(settings.default_route, false)
      else
        redirect session[:return_to]
      end
    end

    get '/auth/logout' do
      warden.raw_session.inspect
      warden.logout
      flash(:rwarden)[:success] = 'You have been logged out'
      redirect url(settings.default_route, false)
    end

  	get '/auth/new' do
  	  halt 403 unless settings.allow_public_signup or !(User.count > 0)
      erb :'rw_new_user.html', :layout=>settings.layout, :locals=>{:recaptcha_sitekey=>settings.recaptcha['sitekey']}
    end

    post '/auth/create' do
      verify_recaptcha if settings.recaptcha[:secret]
      Halt "Could not create account", :layout=>settings.layout unless params[:user]
      params[:user].delete_if {|k,v| v.nil? || v==''}
      @user = User.new(params['user'])
      if @user.save
        warden.set_user(@user)
      	flash(:rwarden)[:success] = warden.message || "Account created"
  	    redirect session[:return_to] || url(settings.default_route, false)
  	  else
  	  	flash(:rwarden)[:error] = "#{warden.message} => #{@user.errors.entries.join('. ')}"
  	  	puts "RW /auth/create #{@user.errors.entries}"
  	  	redirect back #url('/auth/new', false)
  	  end
    end

    post '/auth/unauthenticated' do
    	# I had to remove the condition, since it was not updating return path when it should have.
      session[:return_to] = env['warden.options'][:attempted_path] if !request.xhr? && !env['warden.options'][:attempted_path][/login|new|create/]
      puts "WARDEN ATTEMPTED PATH: #{env['warden.options'][:attempted_path]}"
      puts warden
      # if User.count > 0
        flash(:rwarden)[:error] = warden.message || "Please login to continue"
        redirect url('/auth/login', false)
      # else
      #   flash(:rwarden)[:error] = warden.message || "Please create an admin account"
      #   redirect url('/auth/new', false)
      # end
    end

    get '/auth/protected' do
      warden.authenticate!

      erb :'rw_protected.html', :layout=>settings.layout
    end
    
    get '/auth/admin' do
      warden.authenticate!
      erb :'rw_admin.html', :layout=>settings.layout
    end

  end # App 
end # RackWarden


