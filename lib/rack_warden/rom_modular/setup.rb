module RackWarden
  module Rom
    
    class << self
      attr_accessor :rom_config, :rom_container, :users_relation, :identities_relation, :users_repo, :identities_repo
    end
    
    def self.setup_database(_settings)
      
      adapter = _settings.rom_adapter.to_s
      @rom_config = send "config_#{adapter}", _settings
      
      #@user_relation = Relation.const_get(adapter.capitalize).users
      #@identity_relation = Relation.const_get(adapter.capitalize).identities
      #@rom_config.register_relation @user_relation, @identity_relation
      
      #@rom_config.relation(:users, &Relation.const_get(adapter.capitalize).users)
      #@rom_config.relation(:identities, &Relation.const_get(adapter.capitalize).identities)
      
      # Register relations from procs.
      [:identities, :users].each do |name|
        instance_variable_set :"@#{name}_relation", \
          @rom_config.relation(name, &Relation.const_get(adapter.capitalize).send(name))
      end
      
      # Finalize the rom config
      @rom_container = ROM.container(@rom_config)
      
      # Create rom repos with containers
      @identities_repo = Repository.identities.new(@rom_container)
      @users_repo = Repository.users.new(@rom_container)
      
      # Create entity classes under RackWarden
      RackWarden.const_set(:Identity, Entity.identity(@identities_repo))
      RackWarden.const_set(:User, Entity.user(@users_repo))
      
      # Initialize database tables.
      %w(identities users).each do |name|
        if ENV['RACK_ENV'].to_s[/test/i]
          @rom_container.relation(name).drop_table
        end
        @rom_container.relation(name).create_table
      end
      
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
end #RackWarden