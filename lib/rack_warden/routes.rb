require 'sinatra/namespace'
require 'sinatra/respond_with'

module RackWarden
	module Routes
		def self.included(base)
			base.instance_eval do
		    register Sinatra::Namespace
        
        # Moved to higher-up in the load heirarchy.
  	    #Sinatra::Namespace::NamespacedMethods.prefixed(:require_login, :require_authorization)
				
				# Before does not have access to uri-embedded params yet.				
				#before do
				#end
				
				if defined? STANDALONE
					get '/?' do
						default_page
					end
				end
				
        
        ###  OMNIAUTH NAMESPACE  ###
        logger.info "RW Routes setting up omniauth namespace for #{settings} at #{settings.omniauth_prefix}"
				namespace settings.omniauth_prefix do

    		  # Omniauth callback
          # See this for omniauth.auth hash standardized schema:
          # https://github.com/intridea/omniauth/wiki/Auth-Hash-Schema
          %w(get post).each do |method|
            send(method, "/:provider/callback") do
              logger.debug "RW /provider/callback before-auth env: #{env.object_id}, warden: #{env['warden']}"
              #logger.debug "RW /provider/callback before-auth env: #{env.object_id}, session: #{session.to_h.to_yaml}"
              #warden.logout
              #logger.debug "RW /provider/callback before-auth-after-logout env: #{env.object_id}, warden: #{env['warden']}"
              warden.authenticate!(:omniauth)
              #logger.debug "RW /provider/callback after-auth env: #{env.object_id}, warden: #{env['warden']}"
              #logger.debug "RW /provider/callback after-auth env: #{env.object_id}, session: #{session.to_h.to_yaml}"
              #erb "<pre>#{current_user.to_yaml}</pre>"
              # The .. is to go up one level above the rw_prefix.
              return_to #'/protected'
            end
          end						
				
					# For omniauth failures that happen at the provider, thus
					# hitting the callback url with an 'error' pramater.
					# The callback should redirect the browser here.
				  # You can prevent failure exceptions in dev mode with this:
          #   OmniAuth.config.failure_raise_out_environments = []
					get '/failure' do
            @message = params['message']
            @origin = params['origin']
            @strategy = params['stragety']
            flash[:rw_error] = "The authentication provider returned this message: #{@message}"
            logger.info "RW OmniAuth provider callback had error param: #{params}"
            redirect(settings.default_route)
          end
				
				end # omniauth namespace
				
        
        ###  RW NAMESPACE  ###
        logger.info "RW Routes setting up rw namespace for #{settings} at #{settings.rw_prefix}"
				namespace settings.rw_prefix do
				
					# This is necessary for sinatra-namespace to do nested stuff,
					# due to the namespace module being buggy.
          helpers do
            def settings
              self.class.settings
            end
          end


			    ###  CORE  ###
					
					get '/?' do
					  default_page
					end
					
					get '/login' do
						logger.debug "RW /login action"
						# Trigger authentication on remember_me, in case they haven't hit a protected page yet.
            warden.authenticate :remember_me if settings.allow_remember_me
					  if User.count > 0
					    respond_with :'rw_login'
					  else
					    flash.rw_error = warden.message || "Please create an admin account"
					    redirect url_for('/new')
					  end
					end
					
					post '/login' do
					  warden.authenticate!
					
					  flash.rw_success = warden.message || "Successful login"
					
					  return_to
					end
					
					get '/logout' do
					  #warden.raw_session.inspect
					  #warden.authenticated? # Hack so warden will log out. See  https://github.com/hassox/warden/issues/76.
					  redirect_uri = params[:redirect]
					  if current_user
						  warden.logout
						  #session['identity'] = nil  # I moved this to warden before_logout
						  flash.rw_success = 'You have been logged out'
						end
					  redirect url(redirect_uri || settings.default_route, false)
					end
					
					get '/new' do
					  halt(403, "Not authorized") unless settings.allow_public_signup || !(User.count > 0) || authorized?
					  respond_with :'rw_new_user', :recaptcha_sitekey=>settings.recaptcha['sitekey']
					end
					
					post '/create' do
					  verify_recaptcha if settings.recaptcha[:secret]
					  Halt("Could not create account") unless params[:user]
					  params[:user].delete_if {|k,v| v.nil? || v==''}
					  @user = User.new(params['user'])
					  if @user.save
					    warden.set_user(@user) if settings.login_on_create
					    # TODO: maybe put this line in the user model?
					    @user.activate if settings.mail_options[:delivery_method] == :test
					  	flash.rw_success = warden.message || "Account created"
					  	App.logger.info "RW /.../create succeeded for '#{@user.username rescue nil}'"  # #{@user.errors.entries}"
					    #redirect session[:return_to] || url(settings.default_route, false)
					    return_to url_for(logged_in? ? settings.default_route : '/login')
					  else
					  	flash.rw_error = "There was a problem creating the account: #{warden.message}"  # => #{@user.errors.entries.join('. ')}"
					  	App.logger.info "RW /.../create failed for '#{@user.username rescue nil}'"  # #{@user.errors.entries}"
					  	redirect back
					  end
					end
					
					get '/activate/:code' do
						redirect settings.default_route unless params[:code]
						# TODO: move this logic into User. This should only be 'user = User.activate(params[:code])'
						@user = User.find_for_activate(params[:code])
						if @user.is_a? User #&& user.activated_at == nil
							@user.activate
							warden.set_user(@user) if settings.login_on_activate
							flash.rw_success = "Account activated"
							App.logger.info "RW /.../activate succeeded for '#{@user.username rescue nil}'"  # #{@user.errors.entries}"
							#redirect "/auth/login"
							return_to url_for(logged_in? ? '/' : '/login')
						else
							App.logger.info "RW /.../activate failed for '#{@user}' with errors: #{$!}"
							#halt "Could not activate"
							redirect_error "The activation code was not valid"
						end
					end
					
					post '/unauthenticated' do
						# I had to remove the condition, since it was not updating return path when it should have.
					  session[:return_to] = warden_options[:attempted_path] if !request.xhr? && !warden_options[:attempted_path][Regexp.new(settings.exclude_from_return_to)]
					  App.logger.info "RW attempted path unauthenticated: #{warden_options[:attempted_path]}"
					  App.logger.debug "RW will return-to #{session[:return_to]}"
					  App.logger.debug warden
					  # if User.count > 0
					    flash.rw_error = warden.message || "Please login to continue"
					    redirect url_for('/login')
					  # else
					  #   flash[:rwarden][:error] = warden.message || "Please create an admin account"
					  #   redirect url('/auth/new', false)
					  # end
					end
					
					get "/error" do
						respond_with :'rw_error'
					end					
					
					
					###  UTILITY  ###
				
					get "/testing.?:format?" do
						logger.debug "RW /.../testing request.cookies" + request.cookies.to_yaml
						logger.debug "RW /.../testing response" + response.to_yaml
						logger.debug "RW request headers #{headers.inspect}"
						logger.debug "RW request.accept #{request.accept}"
						logger.debug "RW env['sinatra.accept'] #{env['sinatra.accept']}"
						logger.debug "RW mime_type(ext) #{mime_type(params[:ext])}"
						response.set_cookie '_auth_testing_cookie', :value=>"Hi Im a Cookie", :expires=>Time.now+60, :path=>'/'
						respond_with :'rw_protected' do |f|
							f.yaml { "key: dat"}
						end
						#erb :'rw_protected.html'
					end
				
					get "/is_alive" do
						"YES"
					end
									
					get '/protected' do
					  require_login
					  respond_with :'rw_protected'
					end
					
					get '/account' do
					  require_login
					  if authorized?
              nested_erb :'rw_account.html', :'rw_layout_admin.html', settings.layout
            else
              respond_with :rw_account
            end
					end
					
					get '/admin' do
					  require_authorization
					  #erb :'rw_admin.html', :layout=>settings.layout
					  nested_erb :'rw_index.html', :'rw_layout_admin.html', settings.layout
					  #respond_with :rw_admin
					end
					
					get "/admin/dbinfo" do
						require_authorization
						#erb :'rw_dbinfo.html'
						nested_erb :'rw_dbinfo.html', :'rw_layout_admin.html', settings.layout
					end		
					
					get "/admin/users" do
						require_authorization
						#erb :'rw_dbinfo.html'
						nested_erb :'rw_users.html', :'rw_layout_admin.html', settings.layout
					end		

					get "/admin/identities" do
						require_authorization
						#erb :'rw_dbinfo.html'
						nested_erb :'rw_identities.html', :'rw_layout_admin.html', settings.layout
					end

					get '/admin/sessinfo' do
						require_authorization
						nested_erb :'rw_session.html', :'rw_layout_admin.html', settings.layout
					end
					
          get '/admin/debug' do
            require_authorization
            content_type :text
            session.to_yaml
          end
				
				end # namespace
				
			end
		end
	end
end
