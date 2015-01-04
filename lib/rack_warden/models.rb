
module RackWarden
  
  DataMapper::Logger.new(App.log_path)
  DataMapper.setup(:default, App.database_config)
  puts "RACKWARDEN using database #{App.database_config}"
  # Do DataMapper.repository.adapter to get connection info for this connection.

  #Dir.glob(File.join(File.dirname(__FILE__), 'models', '*.rb')).each {|f| puts File.basename(f); require File.basename(f)}
  Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| puts f; require f}

  # Tell DataMapper the models are done being defined
  DataMapper.finalize

  # Update the database to match the properties of User.
  DataMapper.auto_upgrade!


end # module