# Setup the database connection, schema, etc.
module RackWarden
  
  # Best guess at framework database settings.
  def self.get_database_config
  	#App.logger.debug ActiveRecord::Base.configurations[(RackWarden::App.environment || :development).to_s].to_yaml
    conf = case
    when App.database_config.to_s.downcase == 'file'; "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    when App.database_config.to_s.downcase == 'auto';
	    (ActiveRecord::Base.connection_config rescue nil) ||
	    (ActiveRecord::Base.configurations rescue nil) ||   #[(RackWarden::App.environment || :development).to_s] rescue nil) ||
	    (DataMapper.repository(:default).adapter[:options] rescue nil) ||
    	App.database_default
    when App.database_config; App.database_config
    else App.database_default
    end
    #... sort out environment HERE
    rslt = conf[(RackWarden::App.environment || :development).to_s] || conf
    rslt[:adapter] = 'mysql' if rslt[:adapter]=='mysql2'
    return rslt
  end
  
#   if App.logger.level.to_s[/DEBUG|INFO/]
# 	  ### CAUTION - There may be a file conflict between this and rack::commonlogger.
# 	  DataMapper::Logger.new(settings.log_file)  #$stdout) #App.log_path)
# 	  App.logger.info "RW DataMapper using log_file #{App.log_file}"
#   end
  
  
  # DataMapper setup.
  # Note that DataMapper.repository.adapter will get connection info for this connection.
  DataMapper.setup(:default, get_database_config)
  
  App.logger.debug "RW DataMapper.setup #{DataMapper.repository.adapter.inspect}"
  
  # Careful! This will expose sensitive db login info to the log files.
  App.logger.warn "RW DataMapper repository #{DataMapper.repository.adapter.options.dup.tap{|o| o.delete(:password); o.delete('password')}.inspect}"

	# Load all models.
  App.logger.debug "RW requiring model files in #{File.join(File.dirname(__FILE__), 'models/*')}"
  Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| require f}
	
	# DataMapper finalize
  App.logger.debug "RW DataMapper.finalize"
  # Tell DataMapper the models are done being defined
  DataMapper.finalize

	# DataMapper auto upgrade.
  App.logger.warn "RW DataMapper.auto_upgrade!"
  # Update the database to match the properties of User.
  DataMapper.auto_upgrade!
  
end # RackWarden