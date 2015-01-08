# Setup the database connection, schema, etc.
module RackWarden
  
  # Best guess at framework database settings.
  def self.get_database_config
  	#puts ActiveRecord::Base.configurations[(RackWarden::App.environment || :development).to_s].to_yaml
    #conf = case
    
    when App.database_config.to_s.downcase == 'file'; "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
    when App.database_config.to_s.downcase == 'auto';
	    (ActiveRecord::Base.connection_config rescue nil) ||
	    (ActiveRecord::Base.configurations[(RackWarden::App.environment || :development).to_s] rescue nil) ||
	    (DataMapper.repository(:default).adapter[:options] rescue nil) ||
    	App.database_default
    when App.database_config; App.database_config
    else App.database_default
    end
    #... sort out environment HERE
    #conf = RackWarden::App.environment || :development).to_s
  end
  
  #puts "RW DataMapper using log_path #{App.log_path}"
  ### CAUTION - There may be a file conflict between this and rack::commonlogger.
  DataMapper::Logger.new(settings.log_file)  #$stdout) #App.log_path)
  
  
  DataMapper.setup(:default, get_database_config)
  # Do DataMapper.repository.adapter to get connection info for this connection.
  puts "RW DataMapper.setup #{DataMapper.repository.adapter}"

  #puts "RW requiring model files in #{File.join(File.dirname(__FILE__), 'models/*')}"
  Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| require f}

  #puts "RW DataMapper.finalize"
  # Tell DataMapper the models are done being defined
  DataMapper.finalize

  puts "RW DataMapper.auto_upgrade!"
  # Update the database to match the properties of User.
  DataMapper.auto_upgrade!
  
  # Careful! This will expose sensitive db login info.
  #puts "RW DataMapper repository #{DataMapper.repository.adapter.options}"
  
end # module