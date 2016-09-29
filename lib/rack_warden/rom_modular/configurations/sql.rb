module RackWarden
  module Rom

    def self.config_sql(_settings)
      db_config = get_database_config(_settings)
      _settings.logger.info "RW Rom.config_sql with db config: #{db_config}"
      ROM::Configuration.new(:sql, db_config) #do |config|
            

        # Relations used to be here... should we register them here now?

    
      #end # ROM::Configuration.new
    
    end # def rom_config
    
  end # Rom
end # RackWarden