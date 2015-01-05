
module RackWarden
  
  # Best guess at framework database settings.
  def self.get_database_config
    App.database_config ||
    (ActiveRecord::Base.connection_config rescue nil) ||
    (DataMapper.repository(:default).adapter[:options] rescue nil) ||
    "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
  end
  
  puts "RACKWARDEN DataMapper using log_path #{App.log_path}"
  DataMapper::Logger.new(App.log_path)
  
  puts "RACKWARDEN get_database_config #{get_database_config}"
  DataMapper.setup(:default, get_database_config)
  # Do DataMapper.repository.adapter to get connection info for this connection.

  puts "RACKWARDEN requiring model files in #{File.join(File.dirname(__FILE__), 'models/*')}"
  Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| puts f; require f}

  puts "RACKWARDEN finalizing"
  # Tell DataMapper the models are done being defined
  DataMapper.finalize

  puts "RACKWARDEN DataMapper.auto_upgrade!"
  # Update the database to match the properties of User.
  DataMapper.auto_upgrade!
  
  puts "RACKWARDEN DataMapper repository #{DataMapper.repository.adapter.options}"
  
end # module