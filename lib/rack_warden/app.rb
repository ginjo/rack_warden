# require 'bundler'
# Bundler.require

class RackWarden < Sinatra::Base
  enable :sessions
  register Sinatra::Flash
  
  set :layout, :'rack_warden_layout.html'
  set :default_route, '/'
  set :database, "sqlite://#{Dir.pwd}/rack_warden.sqlite.db"
  
  
  # WBR - This will receive params and a block from the parent "use" statement.
  # This middleware app has been modified to process the parent use-block in
  # the context of the RackWarden class. So you can set settings on RackWarden,
  # when you call "use RackWarden"
  # Example:
  #
  # use RackWarden :layout=>:'my_layout' do |rack_warden_instance, parent_app_instance|
	# 	set :myvar, 'something'
	#	end
	#
	def initialize(parent_app=nil, *args, &block)
		#puts "INITIALIZE RackWarden INSTANCE [parent_app, self, args, block]: #{[parent_app, self, args, block]}"
		# extract options.
		opts = args.last.is_a?(Hash) ? args.pop : {}
		klass = self.class
		if parent_app
			# append views from opts.
			klass.set(:original_views, opts.has_key?(:views) ? klass.views : nil)
			#klass.set(:views => [Array(klass.views), opts.delete(:views)].flatten) if opts[:views]
			# set app settings with remainder of opts.
			klass.set opts if opts.any?
			# eval the use-block from the parent app, in context of this app.
			klass.instance_exec(self, parent_instance, &block) if block_given?
			# do parent_app setup.
			setup_parent_app(parent_app, args, opts)
			#parent_app.class.helpers(RackWardenHelpers) rescue ApplicationController.send(:include, RackWardenHelpers)
		end
		# finally, send parent app to super, but don't send the use-block (thus the empty proc)
		super(parent_app, &Proc.new{})
	end
	
	def setup_parent_app(parent_app, args, opts)
		puts "RACKWARDEN initializing parent app: #{parent_app}"
		puts "RACKWARDEN parent app parents: #{parent_app.class.parents}"
		puts "RACKWARDEN parent app ancestors: #{parent_app.class.ancestors}"
		klass = self.class
		case
		when parent_app.class.ancestors.find{|x| x.to_s=='Sinatra::Base'}
			parent_app.class.helpers(RackWardenHelpers)
			default_parent_views = File.join(Dir.pwd,"views")
		when parent_app.class.parents.find{|x| x.to_s=='ActionDispatch'}
			ApplicationController.send(:include, RackWardenHelpers)
			default_parent_views = File.join(Dir.pwd, "app/views")
		end
		
		new_views = []
		original_views = klass.original_views
		# append parent rails views folder unless opts.has_key?(:views)
		new_views << default_parent_views unless opts.has_key?(:views)
		# append original_views, if original_views
		new_views << original_views if original_views
		klass.set(:views => [Array(klass.views), new_views].flatten.compact.uniq) if new_views.any?
		puts "RACKWARDEN views: #{klass.views}"
	end
	
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
      strategies: [:password],
      # The action is a route to send the user to when
      # warden.authenticate! returns a false answer. We'll show
      # this route below.
      action: 'auth/unauthenticated'
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
      user = User.first(username: params['user']['username'])

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
	    env['warden']
		end

		def current_user
	    warden.user
		end
		
		def logged_in?
	    warden.authenticated?
		end
		
		
	  # TODO: Shouldn't these be in warden block above? But they don't work there for some reason.
	  
	  def valid_user_input?
	    params['user'] && params['user']['username'] && params['user']['password']
	  end
	  
	  # TODO: This doesn't work.
		def create_user
		
			recaptcha
		
			return unless valid_user_input?
			user = User.create(username: params['user']['username'])
			user.password = params['user']['password']
			user.save && warden.set_user(user)
		end
		
 		# reCAPTCHA. See https://www.google.com/recaptcha/admin#site/318693958?setup
 		def recaptcha(skip_redirect=false)
	 		_recaptcha = ActiveSupport::JSON.decode(open("https://www.google.com/recaptcha/api/siteverify?secret=6LdG4v4SAAAAAJxwcS8pZRG371ZucyYg5yVUji_V&response=#{params['g-recaptcha-response']}&remoteip=#{request.ip}").read)
	    puts "RECAPTCHA", _recaptcha
	    #(render action and return) unless recaptcha['success']
	    unless _recaptcha['success'] || skip_redirect
	    	flash(:rwarden)[:error] = "Please confirm you are human."
	    	redirect back 
	    end
	  end
		
  end # RackWardenHelpers
  helpers RackWardenHelpers
  

	# WBR. I disabled this so upstream apps would work.
  get '/auth' do
    erb "Warden authentication for any rack based app", :layout=>settings.layout
  end

  get '/auth/login' do
    erb :'login_user.html', :layout=>settings.layout
  end

  post '/auth/login' do
    warden.authenticate!

    flash(:rwarden)[:success] = warden.message || "Successful login"

		puts "RETURN_TO #{session[:return_to]}"
    if session[:return_to].nil?
      redirect settings.default_route
    else
      redirect session[:return_to]
    end
  end

  get '/auth/logout' do
    warden.raw_session.inspect
    warden.logout
    flash(:rwarden)[:success] = 'You have been logged out'
    redirect settings.default_route
  end

	get '/auth/create' do
    erb :'create_user.html', :layout=>settings.layout
  end

  post '/auth/create' do
    if create_user
    	flash(:rwarden)[:success] = warden.message || "Account created"
	    redirect session[:return_to] || settings.default_route
	  else
	  	flash(:rwarden)[:error] = warden.message || "Could not create account"
	  	redirect url('/auth/create')
	  end
  end

  post '/auth/unauthenticated' do
  	# I had to remove the condition, since it was not updating return path when it should have.
    session[:return_to] = env['warden.options'][:attempted_path] if !request.xhr? && !env['warden.options'][:attempted_path][/login/]
    puts "WARDEN ATTEMPTED PATH: #{env['warden.options'][:attempted_path]}"
    puts warden
    flash(:rwarden)[:error] = warden.message || "Please login to continue"
    redirect url('/auth/login')
  end

  get '/auth/protected' do
    warden.authenticate!

    erb :'rack_warden_protected.html', :layout=>settings.layout
  end
  
end # RackWarden

