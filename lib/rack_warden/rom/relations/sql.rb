require_relative 'base'

module RackWarden

  # For RackWarden, you will likely have a separate one of these for each adapter.
  RomConfig = ROM::Configuration.new(:sql, "sqlite://#{DbPath}") do |config|
    types = ROM::Types
        
    users_rel = config.relation :users do
      #dataset :rack_warden_users     
      schema(:rack_warden_users) do
        
        # Macros for default values. The password functions
        # really belong in the relation or model, not in the schema.
        #UUID = types::String.default { SecureRandom.uuid }
        #attribute :id, UUID
        #pswd = types::String.default {SecureRandom.hex}
        #bcrypt = types::String.default {|r,v| BCrypt::Password.create(r.instance_variable_get :@password)}
        
        # TODO: I dont think the activation, remember, reset codes need to be bcrypt,
        #       can probably just be SecureRandom strings.
        
        attribute :id, types::Int
        attribute :username, types::String
        attribute :email, types::String
        attribute :encrypted_password, Types::BCryptString
        attribute :remember_token, Types::BCryptString
        attribute :remember_token_expires_at, types::DateTime
        attribute :activated_at, types::DateTime
        attribute :activation_code, Types::BCryptString
        attribute :password_reset_code, Types::BCryptString
        
        primary_key :id        
      end # schema
      
      include RelationIncludes
    
    end # users_rel
    
    
    identities_rel = config.relation :identities do
      #dataset :rack_warden_identities    
      schema(:rack_warden_identities) do
        attribute :id, Types::Int
        attribute :user_id, Types::Int
        attribute :email, Types::String
        attribute :provider, Types::String
        attribute :uid, Types::String
        attribute :info, Types::ToYaml
        attribute :credentials, Types::ToYaml
        attribute :extra, Types::ToYaml
        attribute :created_at, Types::DateTime.default { DateTime.now }
        primary_key :id
        primary_key :provider, :uid, :email
      end
      
      include RelationIncludes
      
    end # identities_rel 

    #   begin
    #     puts "RackWarden droping table 'identities' in database: #{identities_rel.dataset}"
    #     config.default.connection.drop_table?(identities_rel.dataset.to_sym)
    #     puts "RackWarden creating table 'identities' in database: #{identities_rel.dataset}"
    #     config.default.connection.create_table?(identities_rel.dataset.to_s) do
    #       # rel.schema.attributes.each do |k,v|
    #       #   name = k.to_sym
    #       #   type = v.primitive.is_a?(Dry::Types::Definition) ? v.primitive.primitive : v.primitive
    #       #   puts "column #{name}, #{type}"
    #       #   column name, type
    #       # end
    #       primary_key :id, Integer
    #       column :user_id, Integer
    #       column :email, String
    #       column :provider, String
    #       column :uid, String
    #       column :info, String
    #       column :credentials, String
    #       column :extra, String
    #       column :created_at, DateTime   #, :default=>DateTime.now  # This doesn't work here as the datetime is frozen.
    #     end
    #     #puts "RackWarden created new table in database: #{identities_rel.dataset}"
    #   rescue
    #     puts "RackWarden trouble creating Identities table: #{$!}"
    #   end
    
  end # RomConfig

end # RackWarden