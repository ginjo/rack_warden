module RackWarden
	module RackWardenClassMethods
	
		def self.registered(app)
		  puts "RW RackWardenClassMethods.registered app #{app}" if !app.production? if !App.production?
			app.initialize_app_class
		end
	
	  # Main RackWarden::App class setup.
	  def initialize_app_class
      puts "RW RackWardenClassMethods.initialize_app_class self #{self}" if !production?
	  	initialize_logging
	  	logger.debug "RW RackWardenClassMethods.initialize_app_class environment: #{environment}, process: #{$0}, self: #{self}"
	  	initialize_config_files
	  	initialize_logging  # again, in case log settings changed in config files.
	  	
			# Setup database.
			
			RackWarden::Rom.setup_database(settings)
			
			use Rack::MethodOverride
	  		  	
	    use Rack::Cookies
	    
	    # Moved... see below.
	    #use(Warden::Manager){ |config| config.replace WardenConfig }
			
	    helpers RackWardenHelpers
			
		  register Sinatra::RespondWith
      respond_to :xml, :json, :js, :txt, :html, :yaml
	    
	  end
	  
	  # This should generally only run once.
	  # Also see App#initialize method.
	  def initialize_settings_from_instance(parent_app_instance, rw_app_instance, *initialization_args)
      options = initialization_args.last.is_a?(Hash) ? initialization_args.pop : Hash.new
	     	  
  	  logger.info "RW initialize_settings_from_instance, self: #{self}"
      logger.debug "RW RackWardenClassMethods.initialize_settings_from_instance parent_app_instance: #{parent_app_instance}"
      logger.debug "RW RackWardenClassMethods.initialize_settings_from_instance rw_app_instance: #{rw_app_instance}"
			logger.debug "RW RackWardenClassMethods.initialize_settings_from_instance initialization_args: #{initialization_args}"
			logger.debug "RW RackWardenClassMethods.initialize_settings_from_instance middleware: #{middleware}"
			
			# TODO: Figure out how to integrate new framework model with rw sublclass settings.
			#setup_framework(parent_app_instance, *initialization_args)
      # Originally in setup_framework:
      load_config_from_hash(options)
      
      # Evaluate 'use' block. Note that settings performed in 'use' block
      # will overwrite any settings set as params, from config file, or from any earlier manipulation.
      #
			# Deprecated: Eval the use-block from the parent app, in context of this app.
			#settings.instance_exec(rw_app_instance, &block) if block_given?
			#
			# Eval the use-block from the parent app, in context of the parent app instance.
			logger.debug "RW yielding to initialization block if block_given? #{block_given?}"
			# TODO:  I don't think passing rw_app_instance here is reliable.
			#        It may be instanciated without a request or env.
			yield(rw_app_instance.settings.settings, rw_app_instance) if block_given?
			
			# Originally in setup_framework:
			load_config_from_hash(:views=>settings.extra_views) if settings.extra_views #&& ![settings.views, opts[:views]].flatten.include?(false)			
			
		  # Set global layout (remember to use :layout=>false in your calls to partials).
		  logger.debug "RW RackWardenClassMethods.initialize_settings_from_instance setting erb layout: #{settings.layout}"
			set :erb, :layout=>settings.layout
			
			# Setup database (possibly again, with new settings).
			#RackWarden.setup_database(settings)
			
			set :sessions, true unless sessions
			
			# Needs to get specific settings from rw & main app.
			#helpers RackWarden::WardenConfig
			#use(Warden::Manager){ |config| config.replace WardenConfig } unless middleware.include?(Warden::Manager)
			unless middleware.find {|m| m[0].name == "Warden::Manager"}
        logger.info "RW using Warden::Manager"
  			use(Warden::Manager) do |config|
          # Create new custom warden config, passing the current class-instance of rw.
          default = WardenConfig.new_with_defaults(settings)
          
          #config.merge!(default)
          #config.merge! settings.warden_config if settings.warden_config
          default.merge_into(config)
          settings.warden_config.merge_into(config) if settings.warden_config
          logger.debug "RW Warden final config: #{config}"
          config
        end
			end
			
			unless middleware.find {|m| m[0].name[/omniauth/i]}
        # We have to encase the proc in a hash,
        # or else the proc will be called when we try to access it,
        # which is too soon.
        use OmniAuth::Builder, &settings.omniauth_config[:proc] if settings.omniauth_config.to_h.has_key?(:proc)
			end
			
  		# Setup flash if not already
  		# TODO: This needs to be handled after RW app subclass is created
			use Rack::Flash, :accessorize=>[:rw_error, :rw_success, :rw_test] | settings.flash_accessories
			
			# So we can get specific rw_prefix loaded correctly.
			helpers RackWarden::Routes
			
			# Apply rw_prefix to omniauth path_prefix, for this rw subclass.
			manipulate_omniauth_settings
			
			# This could go earlier... after the yield.
			initialize_logging
			  			
			#logger.info "RW RackWardenClassMethods.initialize_settings_from_instance compiled views: #{settings.views.inspect}"
			
			set :initialized, true	  
	  end
		
    # def setup_framework(app, *args)
    #   logger.info "RW RackWardenClassMethods.setup_framework app: #{app}, args: #{args}"
    #   
    # 	opts = args.last.is_a?(Hash) ? args.pop : {}
    # 	# Get framework module.
    # 	framework_module = Frameworks.select_framework(app)
    # 	#logger.info "RW selected framework module #{framework_module}"
    # 	
    # 	# Prepend views from framework_module if framework_module exists.
    # 	# TODO: should this line be elsewhere?
    # 	settings.overlay_settings(:views=>framework_module.views_path) if framework_module && ![settings.views, opts[:views]].flatten.include?(false)
    # 	
    # 	# Overlay settings with opts.
    # 	settings.overlay_settings opts				
    # 	
    # 	# Setup framework if framework_module exists.
    # 	framework_module.setup_framework if framework_module
    # end

    # Load config from file, if any exist.
    # Config files are yaml and may contain any settable RW setting,
    # any number of environments as main keys (like :development => config-hash-here),
    # and values that are rw-hash-procs (:proc => code-to-eval-when-setting-is-read).
    # Note that the proc code is read as a string and eval'd to form the proc.
    # Example yaml:
    #     database_config:
    #       # Creates separate databases for each environment
    #       # The outter parentheses (or surrounding single or double quotes)
    #       # are required, or yaml will fail.
    #       proc: ( "sqlite://" + File.join(Dir.getwd, "db", "slackspace.#{environment}.sqlite3.db") )
    #       
    #     development:
    #       layout: rw_development_layout.html
    #       other_setting: bobloblaw
    #
    def initialize_config_files(more_config={})
      logger.debug "RW initialize_config_files, self: #{self}, extra-config: #{more_config}"
	    Hash.new.tap do |hash|
	      settings.config_files.each do |c|
  	      begin
            new_yaml_config = YAML.load_file(File.join(Dir.pwd, c))
            load_config_from_hash(new_yaml_config)
            logger.info "RW initialize_config_files loaded file: #{File.join(Dir.pwd, c)}"
            logger.info "RW initialize_config_files loaded file config: #{new_yaml_config}"
          rescue
            logger.debug "RW initialize_config_files failed to load: #{File.join(Dir.pwd, c)}, error: #{$!}"
          end
        end
        if !more_config.empty?
          logger.info "RW initialize_config_files adding more_config: #{more_config}" 
  	      load_config_from_hash(more_config)
        end
	    end
    end
    
    # Merge hash into rw settings, accounting for hash keys containing:
    # :<rack-environment> (will process the sub-hash for current environment),
    # and hash values containing a :proc=>code-to-eval hash (turn to code into a proc
    # and attach to current config key.
    def load_config_from_hash(input_hash={})
      output_hash = {}
      input_hash.each do |k,v|
        if k.to_s == settings.environment.to_s
          load_config_from_hash(v)
        elsif v.is_a?(Hash) && v.keys[0].to_s == 'proc'
          new_proc = eval("Proc.new {#{v.values[0]}}")
          output_hash[k] = new_proc
        else
          output_hash[k] = v
        end
      end
      overlay_settings output_hash
    end
    
    # Apply new settings on top of existing settings, prepending new views to old views.
    def overlay_settings(new_settings)
      existing_views = settings.views
    	new_views = new_settings.__extract__(:views).values
    	logger.debug "RW RackWardenClassMethods.overlay_settings self: #{self}, new_settings: #{new_settings} "   #settings.object_id #{settings.object_id}"
    	#logger.debug "RW existing_views #{existing_views.inspect}"
    	#logger.debug "RW new_views #{new_views.inspect}"
    	# TODO: Should these next two steps be reversed? 2016-08-02
	  	set :views, [new_views, existing_views].flatten.compact.uniq
    	set new_settings
	  	logger.debug "RW compiled_views"
	  	logger.debug views.to_yaml
	  	settings
    end
    	
    # Initialize logging.
    def initialize_logging(reset=reset_logger)
      #puts "RW - initializing logging with log_path:#{settings.log_path}, log_file:#{settings.log_file}, logger:#{settings.logger}"
	    # We take existing log file from settings, enable sync (disables buffering), then put it back in settings.
    	_log_file = !logging && File.new('/dev/null', 'a') || !reset && settings.log_file || File.new(settings.log_path, 'a+')
	    _log_file.sync = true
	    set :log_file, _log_file
	    set :logger, Logger.new(_log_file, 'daily') unless settings.logger && !reset
	    logger.level = eval "Logger::#{log_level.upcase}"
	    
	    # Setup Rack::CommonLogger
	    if use_common_logger
	    	mw = @middleware.find {|m| Array(m)[0] == Rack::CommonLogger}
		    #@middleware.delete_if {|m| Array(m)[0] == Rack::CommonLogger}
		    mw ? mw[1]=[_log_file] : use(Rack::CommonLogger, _log_file)
	    end
	    
	    # TODO: Do we need to handle ROM logging here?
		  #if logger.level < 2
			  #DataMapper::Logger.new(_log_file)  #$stdout) #settings.log_path)
			  #DataMapper.logger.instance_variable_set :@log, _log_file
			  #DataMapper.logger.instance_variable_set :@level, DataMapper::Logger::Levels[log_level.to_s.downcase.to_sym]
			  # logger.info "RW DataMapper using log_file #{_log_file.inspect}"
		  #end
	    
	    logger.info "RW initialize logging, level: #{logger.level}, _log_file: #{_log_file.inspect}"
	  rescue
	  	puts "RW - There was an error setting up logging: #{$!}"
	  end
	  
	  # Set omniauth path_prefix, for all omniauth builders in this RW subclass, with rw_prefix.
    def manipulate_omniauth_settings
      logger.info "RW set omniauth path_prefix with rw_prefix '#{settings.rw_prefix}'"
      ## This was the old way but turns out you can't set omniauth config per omni-builder,
      ## So see below for global omni config.
      # rw_omniauth_middleware = settings.middleware.select{|m| m[0] == (OmniAuth::Builder)}
      # rw_omniauth_middleware.each do |mw|
      #   old_proc = mw[2]
      #   _app = settings
      #   new_proc = Proc.new do
      #     #logger.debug "RW middlware-proc self: #{self}"
      #     configure {|cfg| cfg.path_prefix = _app.rw_prefix}
      #     instance_exec(&old_proc)
      #   end
      #   mw[2] = new_proc
      # end
      
      OmniAuth.configure do |cfg| 
        cfg.path_prefix = settings.omniauth_prefix
        cfg.logger = settings.logger
      end
    end

	  # Creates uri-friendly codes/keys/hashes from raw unfriendly strings (like BCrypt hashes). 
	  def uri_encode(string)
	  	URI.encode(Base64.encode64(string))
	  end
	  
	  def uri_decode(string)
	  	Base64.decode64(URI.decode(string))
	  end
	  
	  # Generic template rendering. Does not have automatic access to 'controller' environment.
	  # Pass 'object' to be the context of rendered template.
  	# See this for more info on using templates here http://stackoverflow.com/questions/5446283/how-to-use-sinatras-haml-helper-inside-a-model.
	  def render_template(template_name, locals_hash={}, object=self )
		  tmpl = settings.views.collect {|v| Tilt.new(File.join(v, template_name)) rescue nil}.compact[0]
		  if tmpl
		  	tmpl.render(object, locals_hash)
		  else
			  settings.logger.info "RW RackWardenClassMethods.render_template found no templates to render" 
			  nil
			end
		end

	end # RackWardenClassMethods
end # RackWarden