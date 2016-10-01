require 'rom-repository'
require 'rom-sql'
require_relative 'types'


module RackWarden

  class << self
  
    def setup_database(_settings)
            
      # Require all ruby files in a directory, recursively.
      # See http://stackoverflow.com/questions/10132949/finding-the-gem-root
      Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/relations/', '**', '*.rb'), &method(:require))
      Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/repositories/', '**', '*.rb'), &method(:require))
    
      # Register an externally defined relation
      #RomConfig.register_relation AnotherRelation
      
      const_set :RomConfig, case _settings.rom_adapter.to_s
        when 'sql'; rom_config_sql(_settings)
        when 'fmp'; rom_config_fmp(_settings)
      end
      
      # Finalize the rom config
      const_set :RomContainer, ROM.container(RomConfig.dup)
      
      # Create rom repos with containers
      const_set :UserRepo, UserRepoClass.new(RomContainer)
      const_set :IdentityRepo, IdentityRepoClass.new(RomContainer)
      
      Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/entities/', '**', '*.rb'), &method(:require))
      
      
      # Initialize database tables.
      %w(identities users).each do |name|
        if ENV['RACK_ENV'].to_s[/test/i]
          RackWarden::RomContainer.relation(name).drop_table
        end
        RackWarden::RomContainer.relation(name).create_table
      end
    end # setup_database
    
    
    # Best guess at framework database settings.
	  def get_database_config(_settings)
	  	#settings.logger.debug ActiveRecord::Base.configurations[(RackWarden::settings.environment || :development).to_s].to_yaml
	    conf = case
	    when settings.database_config.to_s.downcase == 'existing';
		    (ActiveRecord::Base.connection_config rescue nil) ||
		    (ActiveRecord::Base.configurations rescue nil) ||
		    (DataMapper.repository(:default).adapter[:options] rescue nil)
	    when settings.database_config; settings.database_config
	    end
	    raise "RackWarden could not find an existing database configuration" unless conf
	    _settings.logger.info "RW get_database_config initial conf: #{conf}"
	    
	    #... sort out environment HERE
	    rslt = conf.is_a?(Hash) && conf[(RackWarden::settings.environment).to_sym] || conf
	    settings.logger.info "RW get_database_config rslt: #{rslt.inspect}"
	    return rslt
	  end
  
  end

end # SlackSpace