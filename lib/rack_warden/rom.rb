require 'rom-repository'
require 'rom-sql'
require_relative 'rom/types'


module RackWarden
  module Rom    
    
    def self.setup_database(_settings=App.settings, _attach_to=RackWarden)
      
      _settings.logger.info "RW Rom.setup_database #{_settings.database_config}"
      _settings.logger.debug "RW Rom.setup_database, settings: #{_settings}, attaching-to: #{_attach_to}" if !_settings.production?

      rom_adapter = _settings.rom_adapter
      db_config = get_database_config(_settings)

      #_attach_to.instance_eval do
      
        # Set Rom::Config.
        const_set :Configuration, ROM::Configuration.new(rom_adapter, db_config)
        
        # Load relation classes.
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/relations', rom_adapter.to_s, '*.rb'), &method(:require))
        
        # Register relations.
        %w(identities users).each do |name|
          #Rom::Config.relation(name, Rom::Relations.const_get(rom_adapter.capitalize).const_get(name.capitalize))
          Configuration.register_relation(Rom::Relations.const_get(rom_adapter.capitalize).const_get(name.capitalize))
        end

        # Finalize the rom config.
        const_set :Container, ROM.container(Configuration)
        
        # Load repository classes.
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/repositories', '**', '*.rb'), &method(:require))
        
        # Load entity classes.
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/entities', '**', '*.rb'), &method(:require))
        
        # Alias entity classes to RackWarden namspace
        _attach_to.const_set :Identity, Rom::Entities::Identity
        _attach_to.const_set :User, Rom::Entities::User
        
        # Initialize database tables.
        # TODO: methodize this like in SlackSpace.
        %w(identities users).each do |name|
          if ENV['RACK_ENV'].to_s[/test/i] or ENV['RACK_WARDEN_DROP_TABLES']
            Container.relation(name).drop_table
          end
          Container.relation(name).create_table
        end
      
      #end # _attach_to.instance_eval
      
    end # setup_database
    
    
    # Best guess at framework database settings.
	  def self.get_database_config(_settings=App.settings)
	  	#settings.logger.debug ActiveRecord::Base.configurations[(RackWarden::settings.environment || :development).to_s].to_yaml
	    conf = case
  	    when _settings.database_config.to_s.downcase[/existing|auto/];
  		    (ActiveRecord::Base.connection_config rescue nil) ||
  		    (ActiveRecord::Base.configurations rescue nil) ||
  		    (DataMapper.repository(:default).adapter[:options] rescue nil)
  	    when (_settings.database_config.to_s[/\:\/\//] || _settings.database_config.is_a?(Hash)); _settings.database_config
	    end
	    raise "RackWarden could not find an existing database configuration" unless conf
	    _settings.logger.debug "RW get_database_config initial conf: #{conf}"
	    
	    # Handle rack-env (the environment).
	    conf = conf.is_a?(Hash) && conf[_settings.environment.to_s] || conf
	    
	    # If conf is a hash that looks like:  {'proc' => 'string-of-code to eval'}
	    if conf.is_a?(Hash) && conf['proc']
        conf = eval(conf['proc'])
      end
	    
	    # Force into uri format required by ROM (and supposedly the 'industry standard' now).
	    if conf.is_a?(Hash) && conf[:adapter] && conf[:database]
        conf = "#{conf[:adapter]}://#{conf[:database]}", conf
	    end
	    
	    # Convert sqlite3/mysql2 to sqlite/mysql
	    if conf.is_a?(Array) && conf[0].is_a?(String)
        conf[0].gsub!(/^sqlite3/, 'sqlite')
        conf[0].gsub!(/^mysql2/, 'mysql')
	    end
	    if conf.is_a?(Array) && conf.last.is_a?(Hash) && conf.last[:adapter]
        conf.last[:adapter].gsub!(/sqlite3/, 'sqlite')
        conf.last[:adapter].gsub!(/mysql2/, 'mysql')
	    end
	    
	    _settings.logger.debug "RW get_database_config rslt: #{conf.inspect}"
	    
	    return *conf
	  end
        
  end # Rom
end # RackWarden