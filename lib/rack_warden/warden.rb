module RackWarden
	module WardenConfig
		def self.included(base)
			App.logger.warn "RW loading Warden config into #{base}"

			base.instance_eval do			
			
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
		        :strategies => [:remember_me, :password],
		        # The action is a route to send the user to when
		        # warden.authenticate! returns a false answer. We'll show
		        # this route below.
		        :action => 'auth/unauthenticated'
		      # When a user tries to log in and cannot, this specifies the
		      # app to send the user to.
		      config.failure_app = self
		    end
		
			end # self.included
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
	      	user = User.first(:remember_token => env.remember_token)
	      	if user.is_a?(User) && !user.remember_token.to_s.empty?
						success!(user)
	      		App.logger.warn "RW user logged in with remember_me token '#{user.username}'"
	      	else
	          App.logger.info "RW user failed remember_me token login '#{env.remember_token}'"
	          nil	        	
	        end
	      end # authenticate!
			end # remember_me
			
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
				App.logger.debug "RW after_authentication callback - user: #{user.username}"
      	
      	if user.is_a?(User) && (user.remember_token || auth.params['user']['remember_me'] == '1')
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
			end
			
		end # Warden::Manager
				

				# 	# Old password strategy.
				#   Warden::Strategies.add(:password) do
				#     def valid?
				#       params['user'] && params['user']['username'] && params['user']['password']
				#     end
				# 
				#     def authenticate!
				#     
				# 			# Original RackWarden authenticator. Works great, but doesn't allow extra User processing upon login.
				# 			criteria = params['user']['username']  #.to_s.downcase
				# 		  #user = ( User.first([{:username => '?'}, criteria]) + User.first([{:email => '?'}, criteria]) )
				# 		  #user = User.first(:conditions => ['username = ? collate NOCASE or email = ? collate NOCASE', criteria, criteria])  #(username: params['user']['username'])
				# 		  user = User.first(:conditions => ['username = ? or email = ?', criteria, criteria])  #(username: params['user']['username'])
				# 		  if user.nil?
				# 		    fail!("The username you entered does not exist")
				# 		    App.logger.warn "RW user not found '#{criteria}'"
				# 		  elsif user.authenticate(params['user']['password'])
				# 		  	success!(user)
				# 		  	App.logger.warn "RW user logged in '#{user.username}'"
				# 		  else
				# 		    fail!("Could not log in")
				# 		    App.logger.warn "RW user failed login '#{user.username}'"
				# 		  end
				#       
				#     end # authenticate!
				#   end	# Warden::Strategies password		    
		    
		    
				#   # Older remember_me routine.
				#   Warden::Strategies.add(:remember_me_old) do
				#     def valid?
				#       #env['rack.cookies']['rack_warden_remember_me']
				#       cookies['rack_warden_remember_me']
				#     end
				# 
				#     def authenticate!
				#     	#user = User.first(:remember_token => env['rack.cookies']['rack_warden_remember_me'])
				#     	user = User.first(:remember_token => cookies['rack_warden_remember_me'])
				#     	#App.logger.debug "rack_warden_remember_me token: #{env['rack.cookies']['rack_warden_remember_me']}"
				#     	App.logger.debug "rack_warden_remember_me token: #{cookies['rack_warden_remember_me']}"
				#     	if user.is_a?(User) && user.remember_token
				# 				success!(user)
				#     		user.remember_me
				#     		#cookies['rack_warden_remember_me'] = { :value => user.remember_token , :expires => user.remember_token_expires_at }
				#     		App.logger.warn "RW user logged in with remember_me token '#{user.username}'"
				#     	else
				#         fail!("Could not login with remember_me token")
				#         App.logger.warn "RW user failed remember_me token login '#{env['rack.cookies']['rack_warden_remember_me']}'"		        	
				#       end
				#     end # authenticate!
				#   end # Warden::Strategies remember_me
				    
			#end # instance_eval
    #end # self.included
  end # WardenConfig
end # RackWarden

