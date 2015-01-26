module RackWarden
	module Routes
		def self.included(base)
			base.instance_eval do
			
				# This will break everything.
				#respond_to :erb, :haml, :xml, :html
			
				App.logger.debug "RW loading routes"
			
				get "/auth/testing" do
					settings.logger.debug "RW /auth/testing request.cookies" + request.cookies.to_yaml
					settings.logger.debug "RW /auth/testing response" + response.to_yaml
					response.set_cookie '_auth_testing_cookie', :value=>"Hi Im a Cookie", :expires=>Time.now+60*60, :path=>'/'
					respond_with :'rw_protected'
				end
			
				get "/auth/is_running" do
					"YES"
				end

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
				    flash.rw_error = warden.message || "Please create an admin account"
				    redirect url('/auth/new', false)
				  end
				end
				
				post '/auth/login' do
				  warden.authenticate!
				
				  flash.rw_success = warden.message || "Successful login"
				
				  return_to
				end
				
				get '/auth/logout' do
				  #warden.raw_session.inspect
				  warden.authenticated? # Hack so warden will log out. See  https://github.com/hassox/warden/issues/76.
				  warden.logout
				  flash.rw_success = 'You have been logged out'
				  redirect url(settings.default_route, false)
				end
				
				get '/auth/new' do
				  halt(403, "Not authorized") unless settings.allow_public_signup || !(User.count > 0) || authorized?
				  erb :'rw_new_user.html', :layout=>settings.layout, :locals=>{:recaptcha_sitekey=>settings.recaptcha['sitekey']}
				end
				
				post '/auth/create' do
				  verify_recaptcha if settings.recaptcha[:secret]
				  Halt("Could not create account", :layout=>settings.layout) unless params[:user]
				  params[:user].delete_if {|k,v| v.nil? || v==''}
				  @user = User.new(params['user'])
				  if @user.save
				    warden.set_user(@user) if settings.login_on_create
				    @user.activate if settings.mail_options[:delivery_method] == :test
				  	flash.rw_success = warden.message || "Account created"
				  	App.logger.info "RW /auth/create succeeded for '#{@user.username rescue nil}' #{@user.errors.entries}"
				    #redirect session[:return_to] || url(settings.default_route, false)
				    return_to (logged_in? ? '/auth' : '/auth/login')
				  else
				  	flash.rw_error = "#{warden.message} => #{@user.errors.entries.join('. ')}"
				  	App.logger.info "RW /auth/create failed for '#{@user.username rescue nil}' #{@user.errors.entries}"
				  	redirect back #url('/auth/new', false)
				  end
				end
				
				get '/auth/activate/:code' do
					redirect settings.default_route unless params[:code]
					# TODO: move this logic into User. This should only be 'user = User.activate(params[:code])'
					@user = User.find_for_activate(params[:code])
					if @user.is_a? User #&& user.activated_at == nil
						@user.activate
						warden.set_user(@user) if settings.login_on_activate
						flash.rw_success = "Account activated"
						App.logger.info "RW /auth/activate succeeded for '#{@user.username rescue nil}' #{@user.errors.entries}"
						#redirect "/auth/login"
						return_to (logged_in? ? '/auth' : '/auth/login')
					else
						App.logger.info "RW /auth/activate failed for '#{@user}' with errors: #{$!}"
						halt "Could not activate", :layout=>settings.layout
					end
				end
				
				post '/auth/unauthenticated' do
					# I had to remove the condition, since it was not updating return path when it should have.
				  session[:return_to] = env['warden.options'][:attempted_path] if !request.xhr? && !env['warden.options'][:attempted_path][Regexp.new(settings.exclude_from_return_to)]
				  App.logger.info "RW attempted path unauthenticated: #{env['warden.options'][:attempted_path]}"
				  App.logger.debug "RW will return-to #{session[:return_to]}"
				  App.logger.debug warden
				  # if User.count > 0
				    flash.rw_error = warden.message || "Please login to continue"
				    redirect url('/auth/login', false)
				  # else
				  #   flash[:rwarden][:error] = warden.message || "Please create an admin account"
				  #   redirect url('/auth/new', false)
				  # end
				end
				
				get '/auth/protected' do
				  require_login
				  erb :'rw_protected.html', :layout=>settings.layout
				  #wrap_with(){erb :'rw_protected.html'}
				end
				
				get "/auth/dbinfo" do
					require_authorization
					#erb :'rw_dbinfo.html', :layout=>settings.layout
					nested_erb :'rw_dbinfo.html', :'rw_layout_admin.html', settings.layout
				end
				
				get '/auth/admin' do
				  require_authorization
				  #erb :'rw_admin.html', :layout=>settings.layout
				  nested_erb :'rw_admin.html', :'rw_layout_admin.html', settings.layout
				end
				
				get '/auth/sessinfo' do
					require_authorization
					nested_erb :'rw_session.html', :'rw_layout_admin.html', settings.layout
				end
				
			end
		end
	end
end
