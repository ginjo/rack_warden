require 'rom-repository'
require 'rom-sql'
require_relative 'types'


module RackWarden
  module Rom    
    
    def self.setup_database(_settings, _attach_to=_settings)

      adapter = _settings.rom_adapter
      db_config = get_database_config(_settings)

      _attach_to.instance_eval do
      
        RomConfig = ROM::Configuration.new(adapter, db_config)
        
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/relations', '*.rb'), &method(:require))
        
        # Register relations from procs.
        %w(identities users).each do |name|
          RomConfig.relation(name, Rom::Relations.const_get(adapter.capitalize).const_get(name.capitalize))
        end
        
        # Finalize the rom config
        RomContainer = ROM.container(RomConfig)
        
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/repositories', '*.rb'), &method(:require))
        
        # Create rom repos with containers
        Identities = Rom::Repositories::Identities.new(RomContainer)
        Users = Rom::Repositories::Users.new(RomContainer)
        
        Dir.glob(File.join(File.dirname(__FILE__), 'rom/entities', '*.rb'), &method(:require))
        
        # Create entity classes under RackWarden
        Identity = Rom::Entities::Identity #[Identities]
        User = Rom::Entities::User #[Users]
        
        # Initialize database tables.
        %w(identities users).each do |name|
          if ENV['RACK_ENV'].to_s[/test/i]
            RomContainer.relation(name).drop_table
          end
          RomContainer.relation(name).create_table
        end
      
      end # _attach_to.instance_eval
      
    end # setup_database
    
    
    # Best guess at framework database settings.
	  def self.get_database_config(_settings)
	  	#settings.logger.debug ActiveRecord::Base.configurations[(RackWarden::settings.environment || :development).to_s].to_yaml
	    conf = case
  	    when _settings.database_config.to_s.downcase[/existing|auto/];
  		    (ActiveRecord::Base.connection_config rescue nil) ||
  		    (ActiveRecord::Base.configurations rescue nil) ||
  		    (DataMapper.repository(:default).adapter[:options] rescue nil)
  	    when (_settings.database_config.to_s[/\:\/\//] || _settings.database_config.is_a?(Hash)); _settings.database_config
	    end
	    raise "RackWarden could not find an existing database configuration" unless conf
	    _settings.logger.info "RW get_database_config initial conf: #{conf}"
	    
	    # Handle rack-env (the environment).
	    conf = conf.is_a?(Hash) && conf[_settings.environment.to_s] || conf
	    
	    # Force into uri format required by ROM (and supposedly the 'industry standard' now).
	    if conf.is_a?(Hash)
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
	    
	    _settings.logger.info "RW get_database_config rslt: #{conf.inspect}"
	    
	    return *conf
	  end
        
  end # Rom
end # RackWarden