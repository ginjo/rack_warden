module RackWarden
	module Routes
		def self.included(base)
			base.instance_eval do
			
				App.logger.debug "RW loading routes"
				
				respond_to :xml, :json, :js, :txt, :html, :yaml
				
				# Before does not have access to uri-embedded params yet.				
# 				before do
# 					# flash.rw_test = "Testing RW Flash #{Time.now}"
# 					if request.path_info.to_s[/\.xml\??/]
# 						env['sinatra.accept'] = 'application/xml'
# 					end
# 				end
				
				if defined? ::RACK_WARDEN_STANDALONE
					get '/?' do
						default_page
					end
				end

				namespace settings.rw_prefix do
				
			    helpers do
			      def settings
			        App.settings
			      end
			    end
			    

			    
			    ###  CORE  ###
					
					get '/?' do
					  default_page
					end
					
					get '/login' do
						logger.debug "RW /login action"
						# Trigger authentication on remember_me, in case they haven't hit a protected page yet.
						warden.authenticate :remember_me
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
					  warden.authenticated? # Hack so warden will log out. See  https://github.com/hassox/warden/issues/76.
					  warden.logout
					  flash.rw_success = 'You have been logged out'
					  redirect url(settings.default_route, false)
					end
					
					get '/new' do
					  halt(403, "Not authorized") unless settings.allow_public_signup || !(User.count > 0) || authorized?
					  respond_with :'rw_new_user', :locals=>{:recaptcha_sitekey=>settings.recaptcha['sitekey']}
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
					  	App.logger.info "RW /auth/create succeeded for '#{@user.username rescue nil}' #{@user.errors.entries}"
					    #redirect session[:return_to] || url(settings.default_route, false)
					    return_to url_for(logged_in? ? '/' : '/login')
					  else
					  	flash.rw_error = "#{warden.message} => #{@user.errors.entries.join('. ')}"
					  	App.logger.info "RW /auth/create failed for '#{@user.username rescue nil}' #{@user.errors.entries}"
					  	redirect back #url('/auth/new', false)
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
							App.logger.info "RW /auth/activate succeeded for '#{@user.username rescue nil}' #{@user.errors.entries}"
							#redirect "/auth/login"
							return_to url_for(logged_in? ? '/' : '/login')
						else
							App.logger.info "RW /auth/activate failed for '#{@user}' with errors: #{$!}"
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
				
					get "/testing.?:ext?" do
						logger.debug "RW /auth/testing request.cookies" + request.cookies.to_yaml
						logger.debug "RW /auth/testing response" + response.to_yaml
						logger.debug "RW request headers #{headers.inspect}"
						logger.debug "RW request.accept #{request.accept}"
						logger.debug "RW env['sinatra.accept'] #{env['sinatra.accept']}"
						logger.debug "RW mime_type(ext) #{mime_type(params[:ext])}"
						response.set_cookie '_auth_testing_cookie', :value=>"Hi Im a Cookie", :expires=>Time.now+60, :path=>'/'
						respond_with :'rw_protected'
						#erb :'rw_protected.html'
					end
				
					get "/is_running" do
						"YES"
					end
									
					get '/protected' do
					  require_login
					  respond_with :'rw_protected'
					end
					
					get "/dbinfo" do
						require_authorization
						#erb :'rw_dbinfo.html'
						nested_erb :'rw_dbinfo.html', :'rw_layout_admin.html', settings.layout
					end
					
					get '/admin' do
					  require_authorization
					  #erb :'rw_admin.html', :layout=>settings.layout
					  nested_erb :'rw_admin.html', :'rw_layout_admin.html', settings.layout
					  #respond_with :rw_admin
					end
					
					get '/sessinfo' do
						require_authorization
						nested_erb :'rw_session.html', :'rw_layout_admin.html', settings.layout
					end
				
				end # namespace
				
			end
		end
	end
end
