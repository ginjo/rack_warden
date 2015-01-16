module RackWarden
	module Routes
		def self.included(base)
			base.instance_eval do
			
				App.logger.debug "RW loading routes"
			
			
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
				  warden.logout
				  flash.rw_success = 'You have been logged out'
				  redirect url(settings.default_route, false)
				end
				
				get '/auth/new' do
				  halt 403 unless settings.allow_public_signup || !(User.count > 0) || authorized?
				  erb :'rw_new_user.html', :layout=>settings.layout, :locals=>{:recaptcha_sitekey=>settings.recaptcha['sitekey']}
				end
				
				post '/auth/create' do
				  verify_recaptcha if settings.recaptcha[:secret]
				  Halt "Could not create account", :layout=>settings.layout unless params[:user]
				  params[:user].delete_if {|k,v| v.nil? || v==''}
				  @user = User.new(params['user'])
				  if @user.save
				    warden.set_user(@user)
				  	flash.rw_success = warden.message || "Account created"
				  	App.logger.info "RW /auth/create succeeded for '#{@user.username rescue nil}' #{@user.errors.entries}"
				    #redirect session[:return_to] || url(settings.default_route, false)
				    return_to
				  else
				  	flash.rw_error = "#{warden.message} => #{@user.errors.entries.join('. ')}"
				  	App.logger.info "RW /auth/create errors for '#{user.username rescue nil}' #{@user.errors.entries}"
				  	redirect back #url('/auth/new', false)
				  end
				end
				
				post '/auth/unauthenticated' do
					# I had to remove the condition, since it was not updating return path when it should have.
				  session[:return_to] = env['warden.options'][:attempted_path] if !request.xhr? && !env['warden.options'][:attempted_path][/login|new|create/]
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
				  #warden.authenticate!
				  require_login
				  erb :'rw_protected.html', :layout=>settings.layout
				  #wrap_with(){erb :'rw_protected.html'}
				end
				
				get "/auth/dbinfo" do
					#warden.authenticate!
					require_authorization
					#erb :'rw_dbinfo.html', :layout=>settings.layout
					nested_erb :'rw_dbinfo.html', :'rw_layout_admin.html', settings.layout
				end
				
				get '/auth/admin' do
				  #warden.authenticate!
				  require_authorization
				  #erb :'rw_admin.html', :layout=>settings.layout
				  nested_erb :'rw_admin.html', :'rw_layout_admin.html', settings.layout
				end
				
				get '/auth/sessinfo' do
					#warden.authenticate!
					require_authorization
					nested_erb :'rw_session.html', :'rw_layout_admin.html', settings.layout
				end
				
			end
		end
	end
end
