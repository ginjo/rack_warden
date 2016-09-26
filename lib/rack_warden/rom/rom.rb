require 'rom-repository'
require 'rom-sql'


module RackWarden

  DbPath = File.join(Dir.getwd, 'rack_warden.sqlite3.db')
  
  require_relative 'types'

  # Require all ruby files in a directory, recursively.
  # See http://stackoverflow.com/questions/10132949/finding-the-gem-root
  Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/relations/', '**', '*.rb'), &method(:require))
  Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/repositories/', '**', '*.rb'), &method(:require))

  # Register the externally defined relation
  #RomConfig.register_relation AnotherRelation
  
  # Finalize the rom config
  RomContainer = ROM.container(RomConfig)
  
  # Create rom repos with containers
  UserRepo = UserRepoClass.new(RomContainer)
  IdentityRepo = IdentityRepoClass.new(RomContainer)
  
  Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/rom/entities/', '**', '*.rb'), &method(:require))
  
  
  # Initialize database tables.
  %w(identities users).each do |name|
    if ENV['RACK_ENV'].to_s[/test/i]
      RackWarden::RomContainer.relation(name).drop_table
    end
    RackWarden::RomContainer.relation(name).create_table
  end

end # SlackSpace