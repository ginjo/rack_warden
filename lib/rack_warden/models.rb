
module RackWarden
  
  puts "RACKWARDEN DataMapper using log_path #{App.log_path}"
  DataMapper::Logger.new(App.log_path)
  
  
  if App.database_config
    puts "RACKWARDEN App.database_config #{App.database_config}"
    puts "RACKWARDEN DataMapper.setup #{App.database_config}"
    DataMapper.setup(:default, App.database_config)

    # Do DataMapper.repository.adapter to get connection info for this connection.

    #Dir.glob(File.join(File.dirname(__FILE__), 'models', '*.rb')).each {|f| puts File.basename(f); require File.basename(f)}
    puts "RACKWARDEN requiring model files in #{File.join(File.dirname(__FILE__), 'models/*')}"
    Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| puts f; require f}

    # Tell DataMapper the models are done being defined
    puts "RACKWARDEN finalizing"
    DataMapper.finalize

    # Update the database to match the properties of User.
    puts "RACKWARDEN DataMapper.auto_upgrade!"
    DataMapper.auto_upgrade!
    
    puts "RACKWARDEN DataMapper repository #{DataMapper.repository.adapter.options}"
  end


end # module