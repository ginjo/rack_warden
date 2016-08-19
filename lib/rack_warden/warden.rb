# MANAGERS=[]
# WARDENS=[]
# class Warden::Manager
#   class << self
#     alias_method :new_original, :new
#     def new(*args)
#       m = super(*args)
#       MANAGERS << m
#       m
#     end
#   end
# end
# class Warden::Proxy
#   class << self
#     alias_method :new_original, :new
#     def new(*args)
#       w = super(*args)
#       WARDENS << w
#       store_object(w.env['rack.session'])
#       w
#     end
#   end
# end
# 
# def store_object(obj)
#   File.open("/Users/wbr/Desktop/WardenSessions/#{obj.object_id}.yml",'w') do |h| 
#      h.write obj.to_h.inspect
#   end
# end




# For more info on the methods available in warden proxy, see the following.
# http://www.rubydoc.info/github/hassox/warden/Warden/Proxy
# http://www.rubydoc.info/github/hassox/warden/Warden/Strategies
# http://www.rubydoc.info/github/hassox/warden/Warden/Manager
#
module RackWarden

	module WardenConfig
		
		# TODO: Document here what class/module is including this module?
		# 
		def self.included(base)
			App.logger.warn "RW loading Warden config into #{base}"
			base.instance_eval do
        App.logger.debug "RW evaluating WardenConfig code within #{base} instance"
        
        
    		###  OMNIAUTH CODE  ###
    		###  See http://www.rubydoc.info/github/intridea/omniauth/OmniAuth/Builder
    		###
    		
    		# Tried this to fix slack csrf error, but it didn't help,
    		# and it broke the other providers.
    		#OmniAuth.config.full_host = ENV['OMNIAUTH_HOST_NAME']
    		
        use OmniAuth::Strategies::Developer
        use OmniAuth::Builder do
          App.logger.debug "RW setting up omniauth providers within #{self}"
          # GitHub API v3 lets you set scopes to provide granular access to different types of data:
          provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'], :scope=> 'user:email' if App.omniauth_adapters.include?('omniauth-github') #, scope: "user,repo,gist"
          # Per the omniauth sinatra example @ https://github.com/intridea/omniauth/wiki/Sinatra-Example
          #provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp')
          #provider :identity, :fields => [:email]
          # See google api docs: https://developers.google.com/identity/protocols/OAuth2
          provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'] if App.omniauth_adapters.include?('omniauth-google-oauth2')
          if App.omniauth_adapters.include?('omniauth-slack'); provider :slack,
            ENV['SLACK_OAUTH_KEY'],
            ENV['SLACK_OAUTH_SECRET'],
            scope: 'identity.basic' ###,identity.email,identity.team,identity.avatar'
            #:setup => lambda{|env| env['omniauth.strategy'].options[:redirect_uri] = "#{ENV['SLACKSPACE_BASE_URL']}/auth/slack/callback" } \
            #:callback_url => "http://#{ENV['SLACKSPACE_BASE_URL']}/auth/slack/callback?" \
          end
          #provider :slack, ENV['SLACK_OAUTH_KEY'], ENV['SLACK_OAUTH_SECRET'], scope: 'identify,team:read,incoming-webhook,channels:read', :name=>'slack_full' #,users:read'
        end
    		###  END OMNIAUTH CODE  ###
			
		    use Warden::Manager do |config|
          # Tell Warden how to save our User info into a session.
          # Sessions can only take strings, not Ruby code, we'll store
          # the User's `id`
          config.serialize_into_session{|user| user.id }
          # Now tell Warden how to take what we've stored in the session
          # and get a User from that information.
          config.serialize_from_session{|id| User.get(id) || Identity.get(id)}
        
          config.scope_defaults :default,
            # "strategies" is an array of named methods with which to
            # attempt authentication. We have to define this later.
            :strategies => [:remember_me, :password],
            # The action is a route to send the user to when
            # warden.authenticate! returns a false answer. We'll show
            # this route below.
            :action => "#{App.rw_prefix}/unauthenticated"
          # When a user tries to log in and cannot, this specifies the
          # app to send the user to.
          config.failure_app = self
		    end
		
			end # base.instance_eval
		end # self.included



    module Warden::Strategies
    
    	# TODO: Add basic-auth stragety.
    	# From Rack documentation - this is all you need for basic auth in Sinatra.
	  	# use Rack::Auth::Basic, "Protected Area" do |username, password|
	  	#   username == 'foo' && password == 'bar'
	  	# end
    


	    add(:password) do
	    	#App.logger.debug "RW WardenStrategies.add(password) self #{self.class}"
	    	
	      def valid?
	        params['user'] && params['user']['username'] && params['user']['password']
	      end
	
	      def authenticate!
	      	# User-class based authenticator. See below for old local-based authenticator
	      	App.logger.debug "RW authenticate! method self #{self.class}"
	      	App.logger.debug "RW authenticating with password"
	      	user = User.authenticate(params['user']['username'], params['user']['password'])
	      	if user.is_a? User
	      		success!(user)
	        	App.logger.warn "RW user logged in '#{user.username}'"
	        else
	          fail!("Could not login")
	          App.logger.warn "RW user failed regular login '#{params['user']['username']}'"		        	
	        end
	        
	      end # authenticate!
	    end	# Warden::Strategies password
    
    
	    # Newer remember_me routine
			add(:remember_me) do
			  def valid?
			  	App.logger.debug "RW checking existence of remember_token cookie: #{env['rack.request.cookie_hash']['rack_warden_remember_me']}"
			    #env['rack.cookies']['rack_warden_remember_me']
			    #env['rack.request.cookie_hash']['rack_warden_remember_me']
			    env.remember_token
			  end
			
	      def authenticate!
	      	App.logger.debug "RW authenticate!(:remember_me) self #{self.class}"
	      	App.logger.debug "RW authenticating with rack_warden_remember_me token: #{env.remember_token}"
	      	user = User.query(:remember_token => env.remember_token).first
	      	if user.is_a?(User) && !user.remember_token.to_s.empty?
						success!(user)
	      		App.logger.warn "RW user logged in with remember_me token '#{user.username}'"
	      	else
	          App.logger.info "RW user failed remember_me token login '#{env.remember_token}'"
	          nil	        	
	        end
	      end # authenticate!
			end # remember_me
			
			###  OMNIAUTH CODE  ###
      add(:omniauth) do
        
        def valid?
          env['omniauth.auth'].is_a?(Hash) || env['omniauth.auth'].is_a?(OmniAuth::AuthHash)
        end
        
        
        # TODO: Clean this up... something smells fishy.
        #       When to overwrite existing identity?
        #       When to create new identity?
        #       Should we use user_id, or abandon it?
        #       
        def authenticate!
          begin
            identity = IdentityRepo.locate_or_create_from_auth_hash(env['omniauth.auth'])
            #puts env['omniauth.auth'].to_yaml
            if identity.uid
              session['identity'] = identity.id
              #puts "Strategy#authenticate! SUCCESS"
              success!(identity.user)
            else
              #puts "Strategy#authenticate! FAIL"
              fail!("Could not authenticate omniauth identity")
            end
          rescue Exception
            RackWarden::App.logger.warn "RW strategy for omniauth has raised an exception."
            RackWarden::App.logger.warn "RW #{$!}"
            fail!("Could not authenticate omniauth identity, exception raised")
            # Should this really throw an exception here? Isn't there a friendly failure action?
            raise $!
          end
        end
        
      end
      ###  END OMNIAUTH CODE  ###
			
		end # Warden::Strategies
		
		
		# See http://www.rubydoc.info/github/hassox/warden/Warden/Hooks for info on callback params.

    class Warden::Manager
	    
	    before_failure do |env,opts|
	      env['REQUEST_METHOD'] = 'POST'
	    end
			
			after_authentication  do |user, auth, opts|
				#App.logger.debug "RW after_authentication callback - self: #{self}"
				#App.logger.debug "RW after_authentication callback - auth methods: #{auth.methods.sort}"
				#App.logger.debug "RW after_authentication callback - opts: #{opts.inspect}"
				#App.logger.debug "RW after_authentication callback - auth.manager: #{auth.manager.inspect}"
				#App.logger.debug "RW after_authentication callback - user: #{user.username}"
      	
      	if user.is_a?(User) && (user.remember_token || (auth.params['user'] && auth.params['user']['remember_me'] == '1'))
      		App.logger.debug "RW after_authenticate user.remember_me '#{user.username}'"
      		user.remember_me
					
					# We have no path to response object here :(
					#auth.response.set_cookie 'rack_warden_remember_me', :value => user.remember_token , :expires => user.remember_token_expires_at
					# So we have to do this
			  	auth.env.remember_token = { :value => user.remember_token , :expires => user.remember_token_expires_at.to_time }   #user.remember_me # sets its remember_token attribute to some large random value and returns the value.
					App.logger.debug "RW cookie set auth.env.remember_token: #{auth.env.remember_token}"
				end
			end
			
			before_logout do |user, auth, opts|
				App.logger.debug "RW before_logout callback - self: #{self}"
				App.logger.debug "RW before_logout callback - auth: #{auth.instance_variables}"
				App.logger.debug "RW before_logout callback - opts: #{opts.inspect}"
				App.logger.debug "RW before_logout callback - user: #{user.inspect}"
			  
			  #auth.response.set_cookie 'rack_warden_remember_me', nil
			  App.logger.debug "RW cookie unset 'rack_warden_remember_token': #{auth.env.remember_token}"
			  auth.env.remember_token = nil

			  user && user.forget_me
			  
			  auth.env['rack.session']['identity'] = nil
			end
			
		end # Warden::Manager

  end # WardenConfig
end # RackWarden

