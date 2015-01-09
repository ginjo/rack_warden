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
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views
    set :initialized, false
    
    # Load config from file, if any exist.
    Hash.new.tap do |hash|
      config_files.each {|c| hash.merge!(YAML.load_file(File.join(Dir.pwd, c))) rescue nil}
      set hash
    end
    
		begin
	    enable :logging
	    set :log_file, File.new(settings.log_path, 'a+')
	    settings.log_file.sync = true
	    use Rack::CommonLogger, settings.log_file
	  rescue
	  end
  
  
    # WBR - This will receive params and a block from the parent "use" statement.
    # This middleware app has been modified to process the parent use-block in
    # the context of the RackWarden class. So you can set settings on RackWarden,
    # when you call "use RackWarden::App"
    # Example:
    #
    # use RackWarden::App :layout=>:'my_layout' do |rack_warden_instance, app|
  	# 	set :myvar, 'something'
  	#	end
  	#
  	def initialize(parent_app_instance=nil, *args, &block)
  		#@app = parent_app_instance
  		super(parent_app_instance, &Proc.new{})
  	  initialization_args = args.dup
  		#puts "RW INITIALIZE middleware instance [app, self, args, block]: #{[app, self, args, block]}"
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
      		#original_views = self.class.original_views
      		# append parent rails views folder unless opts.has_key?(:views)
      		#new_views << framework_module.views_path unless opts[:views]==false #opts.has_key?(:views)
      		# append original_views, if original_views
      		#new_views << original_views if original_views
      		#self.class.set(:views => [new_views, Array(self.class.views)].flatten.compact.uniq) if new_views.any?
      		
      		new_views.unshift settings.original_views
      		new_views.unshift framework_module.views_path unless settings.views==false
      		new_views.unshift settings.views
      		settings.set :views, new_views.flatten.compact.uniq
      		
      		puts "RW compiled views: #{settings.views.inspect}"
    		end
    		settings.set :initialized, true
  		end
  		# finally, send parent app to super, but don't send the use-block (thus the empty proc)
  		#super(app, &Proc.new{})
  	end
  	
  	# This might be breaking older rails installations.
		# if development?
		# 	def call(env)  
		# 		#puts "RW instance.app #{app}"
		# 	  #puts "RW instance.call(env) #{env.to_yaml}"
		# 	  env['rack_warden'] = self
		# 	  super(env)
		# 	end 
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
      	criteria = params['user']['username']  #.to_s.downcase
        #user = ( User.first([{:username => '?'}, criteria]) + User.first([{:email => '?'}, criteria]) )
        user = User.first(:conditions => ['username = ? collate nocase or email = ? collate nocase', criteria, criteria])  #(username: params['user']['username'])

        if user.nil?
          fail!("The username you entered does not exist")
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
  		
			def authorized?(authenticate_on_fail=false)
				unless current_user.authorized?(request)
					if authenticate_on_fail
						flash(:rwarden)[:error] = ("Please login to continiue")
						redirect "/auth/login"
					else
						flash(:rwarden)[:error] = ("You are not authorized to do that")
						redirect back
					end
				end
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
				# 	erb settings.layout do
				# 		erb :'rw_layout_admin.html' do
				# 			erb :'rw_index.html'
				# 		end
				# 	end
				
				# 	erb :'rw_layout_admin.html', :layout=>settings.layout do
				# 		erb :'rw_index.html'
				# 	end
				
				# 	wrap_with do
				# 		erb :'rw_index.html'
				# 	end
				nested_erb :'rw_index.html', :'rw_layout_admin.html', settings.layout    #settings.layout
  	  end
			
  	  def nested_erb(*list)
  	  	template = list.shift
  	  	counter =0
  	  	list.inject(template) do |tmplt, lay|
  	  		#puts "RW LAYOUTS lay: #{lay}, rslt: #{tmplt}"
  	  		erb tmplt, :layout=>lay
  	  	end
  	  end
  	  
      def return_to(fallback=settings.default_route)
      	redirect session[:return_to] || url(fallback, false)
      end
      
      def test_view_helper
      	return unless current_user
      	erb "Current User: #{current_user.username}"
      end
      
      def rack_warden
      	self
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

      return_to
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
  	    #redirect session[:return_to] || url(settings.default_route, false)
  	    return_to
  	  else
  	  	flash(:rwarden)[:error] = "#{warden.message} => #{@user.errors.entries.join('. ')}"
  	  	puts "RW /auth/create #{@user.errors.entries}"
  	  	redirect back #url('/auth/new', false)
  	  end
    end

    post '/auth/unauthenticated' do
    	# I had to remove the condition, since it was not updating return path when it should have.
      session[:return_to] = env['warden.options'][:attempted_path] if !request.xhr? && !env['warden.options'][:attempted_path][/login|new|create/]
      puts "RW attempted path: #{env['warden.options'][:attempted_path]}"
      puts "RW will return-to #{session[:return_to]}"
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
      #authorized?
      erb :'rw_protected.html', :layout=>settings.layout
      #wrap_with(){erb :'rw_protected.html'}
    end
    
    get "/auth/dbinfo" do
    	warden.authenticate!
    	authorized?
    	#erb :'rw_dbinfo.html', :layout=>settings.layout
    	nested_erb :'rw_dbinfo.html', :'rw_layout_admin.html', settings.layout
    end
    
    get '/auth/admin' do
      warden.authenticate!
      authorized?
      #erb :'rw_admin.html', :layout=>settings.layout
      nested_erb :'rw_admin.html', :'rw_layout_admin.html', settings.layout
    end

  end # App 
end # RackWarden


