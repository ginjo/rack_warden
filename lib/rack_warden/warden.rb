require 'forwardable'

module RackWarden

	###  OMNIAUTH CODE  ###
	###  See http://www.rubydoc.info/github/intridea/omniauth/OmniAuth/Builder
	###    		
	
	# Tried this to fix slack csrf error, but it didn't help,
	# and it broke the other providers.
	#OmniAuth.config.full_host = ENV['OMNIAUTH_HOST_NAME']
	
  # use OmniAuth::Strategies::Developer
  # use OmniAuth::Builder do
  #   App.logger.debug "RW setting up omniauth providers within #{self}"
  #   # Per the omniauth sinatra example @ https://github.com/intridea/omniauth/wiki/Sinatra-Example
  #   #provider :open_id, :store => OpenID::Store::Filesystem.new('/tmp')
  #   #provider :identity, :fields => [:email]
  # 
  #   # GitHub API v3 lets you set scopes to provide granular access to different types of data:
  #   if App.omniauth_adapters.include?('omniauth-github') 
  #     provider :github, ENV['GITHUB_KEY'], ENV['GITHUB_SECRET'],
  #       name: 'rw_github',
  #       scope: 'user:email'
  #   end
  # 
  #   # See google api docs: https://developers.google.com/identity/protocols/OAuth2
  #   if App.omniauth_adapters.include?('omniauth-google-oauth2')
  #     provider :google_oauth2, ENV['GOOGLE_KEY'], ENV['GOOGLE_SECRET'],
  #       name: 'rw_google'
  #   end
  #   
  #   # Slack oauth2
  #   if App.omniauth_adapters.include?('omniauth-slack');
  #     provider :slack, ENV['SLACK_OAUTH_KEY'], ENV['SLACK_OAUTH_SECRET'],
  #       name: 'rw_slack',
  #       scope: 'identity.basic' #,identity.email,identity.team' #,identity.avatar'
  #       #scope: 'identify,team:read,incoming-webhook,channels:read,users:read'
  #       #setup: lambda{|env| env['omniauth.strategy'].options[:redirect_uri] = "#{ENV['SLACKSPACE_BASE_URL']}/auth/slack/callback" }
  #       #callback_url: "http://#{ENV['SLACKSPACE_BASE_URL']}/auth/slack/callback?"
  #       #path_prefix: '/some_other_prefix'  #Make sure RackWarden 'rw_prefix' is in tune with this setting.
  #   end
  # end
	###  END OMNIAUTH CODE  ###
	
	# There is a looping paradox here:
	# You need WardenConfig to exist so that user can customize it before loading RW.
	# But WardenConfig needs to know which RW app dup it'w being setup from.

  # TODO: Try make WardenConfig a subclass of Warden::Config for the purpose of defining
  # the setup method(s).
  # Then create a new config from that class to be manipulated by end-user-dev, and
  # eventually 'use'd in rw app dup.
  class WardenConfig < Warden::Config
    # Attach forwarding hooks to config object for Warden callback hooks.
    # This is only good for this single config object.
    extend Forwardable
    forwardable_hooks = Warden::Hooks.instance_methods.select {|h| !h.to_s[/^_/]}
    def_delegators Warden::Manager, *forwardable_hooks
    
    def self.new_with_defaults(rw_app=RackWarden::App, config=new)
      rw_app.logger.debug "RW WardenConfig.new_with_defaults"
      
      config.serialize_into_session{|user| user.id }

      config.serialize_from_session{|id| User.get(id) || Identity.get(id)}
    
      config.scope_defaults :default,
        :strategies => [:remember_me, :password],
        :action => rw_app.settings.warden_failure_action.is_a?(Proc) ? Proc.call(rw_app) : rw_app.settings.warden_failure_action

      config.failure_app = rw_app.settings.warden_failure_app #.is_a?(Proc) ? settings.warden_failure_app.call(self) : settings.warden_failure_app
      
      config.before_failure do |env,opts|
        rw_app.logger.info "RW warden before_failure, opts: #{opts}"
        env['REQUEST_METHOD'] = 'POST'
      end
  
  		config.after_authentication  do |user, auth, opts|
      	if user.is_a?(User) && (!user.remember_token.to_s.empty? || (auth.params['user'] && auth.params['user']['remember_me'] == '1'))
      		rw_app.logger.info "RW warden after_authenticate, user.remember_me '#{user.username}'"
      		user.remember_me
  				
  				# We have no path to response object here :(
  				#auth.response.set_cookie 'rack_warden_remember_me', :value => user.remember_token , :expires => user.remember_token_expires_at
  				# So we have to do this
  		  	auth.env.remember_token = { :value => user.remember_token , :expires => user.remember_token_expires_at.to_time }   #user.remember_me # sets its remember_token attribute to some large random value and returns the value.
  				rw_app.logger.debug "RW cookie set auth.env.remember_token: #{auth.env.remember_token}"
  			end
  		end
  		
  		config.before_logout do |user, auth, opts|  			
  			user && user.forget_me
  		  
  		  #auth.response.set_cookie 'rack_warden_remember_me', nil  ## doesn't work, there is no auth.response object !!!
  		  rw_app.logger.debug "RW cookie unset 'rack_warden_remember_token': #{auth.env.remember_token}"
  		  auth.env.remember_token = nil
  		end
  		
  		rw_app.logger.debug config
      config   
    end # new_with_defaults
  end # WardenConfig
  

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
        	App.logger.info "RW warden password-user logged in '#{user.username}'"
        else
          fail!("Could not login")
          App.logger.info "RW warden password-user failed regular login '#{params['user']['username']}'"		        	
        end
      end # authenticate!
    end	# password strategy
  
		add(:remember_me) do
		  def valid?
		  	App.logger.debug "RW checking existence of remember_token cookie: #{env['rack.request.cookie_hash']['rack_warden_remember_me']}"
		    #env['rack.cookies']['rack_warden_remember_me']
		    #env['rack.request.cookie_hash']['rack_warden_remember_me']
		    env.remember_token.to_s != ''
		  end
		
      def authenticate!
      	App.logger.debug "RW authenticate!(:remember_me) self #{self.class}"
      	App.logger.debug "RW authenticating with rack_warden_remember_me token: #{env.remember_token}"
      	user = User.query(:remember_token => env.remember_token).first
      	if user.is_a?(User) && !user.remember_token.to_s.empty?
					rslt = success!(user)
      		App.logger.info "RW warden remember-me-user logged in with remember_me token '#{user.username}'"
      		rslt
      	else
          App.logger.debug "RW warden remember-me-user failed remember_me token login '#{env.remember_token}'"
          nil	        	
        end
      end # authenticate!
		end # remember_me strategy
		
    add(:omniauth) do
      def valid?
        env['omniauth.auth'].is_a?(Hash) || env['omniauth.auth'].is_a?(OmniAuth::AuthHash)
      end
      
      def authenticate!
        begin
          App.logger.debug "RW Warden Strategy Omniauth 'authenticate!' using env['omniauth.auth']"
          #App.logger.debug env['omniauth.auth'].to_h.to_yaml
          identity = IdentityRepo.upsert_from_auth_hash(env['omniauth.auth'])
          user = identity.user if identity
          #App.logger.debug env['omniauth.auth'].to_yaml
          #App.logger.debug env['omniauth.auth'].to_h.to_yaml
          #App.logger.debug identity.to_yaml
          if (identity && user = identity.user)
            App.logger.debug "RW Warden Strategy Omniauth retrieved/created identity: #{identity}, guid:#{identity.guid}, self: #{self}"
            App.logger.info "RW warden omniauth authenticate! SUCCESS"
            # 'success()' is different from 'set_user()', but I'm not sure why the difference.
            # If we don't use 'set_user()' the warden object is not considered logged in yet.
            env['warden'].set_user user
            env['warden'].session['identity'] = identity.id #if env['warden'].authenticated?
            success!(user)
          else
            App.logger.info "RW warden omniauth authenticate! FAIL"
            fail!("Could not authenticate omniauth identity")
          end
        rescue Exception
          App.logger.warn "RW strategy for omniauth has raised an exception."
          App.logger.warn "RW #{$!}"
          fail!("Could not authenticate omniauth identity, exception raised: #{$! if ENV['RACK_ENV'] != 'production'}")
          # Should this really throw an exception here? Isn't there a friendly failure action?
          #raise $!
        end
      end # authenticate!
    end # omniauth strategy
		
	end # Warden::Strategies
		
  # See http://www.rubydoc.info/github/hassox/warden/Warden/Hooks for info on callback params.

  # class Warden::Manager
  # 	    
  #   before_failure do |env,opts|
  #     env['REQUEST_METHOD'] = 'POST'
  #   end
  # 	
  # 	after_authentication  do |user, auth, opts|
  # 		#App.logger.debug "RW after_authentication callback - self: #{self}"
  # 		#App.logger.debug "RW after_authentication callback - auth methods: #{auth.methods.sort}"
  # 		#App.logger.debug "RW after_authentication callback - opts: #{opts.inspect}"
  # 		#App.logger.debug "RW after_authentication callback - auth.manager: #{auth.manager.inspect}"
  # 		#App.logger.debug "RW after_authentication callback - user: #{user.username}"
  # 		
  # 		# This works! But I don't think it's the right place to set the identity.
  #     # if auth.env['omniauth.auth'] && auth.env['warden'].authenticated?
  #     # 	identity = IdentityRepo.upsert_from_auth_hash(auth.env['omniauth.auth'])
  #     # 	auth.env['warden'].session['identity'] = identity.id
  #     # end
  # 			
  #   	
  #   	if user.is_a?(User) && (!user.remember_token.to_s.empty? || (auth.params['user'] && auth.params['user']['remember_me'] == '1'))
  #   		App.logger.info "RW after_authenticate user.remember_me '#{user.username}'"
  #   		user.remember_me
  # 			
  # 			# We have no path to response object here :(
  # 			#auth.response.set_cookie 'rack_warden_remember_me', :value => user.remember_token , :expires => user.remember_token_expires_at
  # 			# So we have to do this
  # 	  	auth.env.remember_token = { :value => user.remember_token , :expires => user.remember_token_expires_at.to_time }   #user.remember_me # sets its remember_token attribute to some large random value and returns the value.
  # 			App.logger.debug "RW cookie set auth.env.remember_token: #{auth.env.remember_token}"
  # 		end
  # 	end
  # 	
  # 	before_logout do |user, auth, opts|
  # 		App.logger.debug "RW before_logout callback - self: #{self}"
  # 		App.logger.debug "RW before_logout callback - auth: #{auth.instance_variables}"
  # 		App.logger.debug "RW before_logout callback - opts: #{opts.inspect}"
  # 		App.logger.debug "RW before_logout callback - user: #{user.inspect}"
  # 		#App.logger.debug "RW before_logout callback - auth.env: #{auth.env.keys}"
  # 		#App.logger.debug "RW before_logout callback - auth.env['rack.session']: #{auth.env['rack.session'].to_h.to_yaml}"
  # 		
  # 		user && user.forget_me
  # 	  
  # 	  #auth.response.set_cookie 'rack_warden_remember_me', nil  ## doesn't work, there is no auth.response object !!!
  # 	  App.logger.debug "RW cookie unset 'rack_warden_remember_token': #{auth.env.remember_token}"
  # 	  auth.env.remember_token = nil
  # 	  
  # 	  #auth.env['warden'].session['identity'] = nil  # This bombs "Warden::NotAuthenticated at /session/slackspace/callback
  #                                                   # :default user is not logged in"
  # 	  #auth.env['rack.session']['identity'] = nil
  # 	end
  # 	
  # end # Warden::Manager

end # RackWarden

