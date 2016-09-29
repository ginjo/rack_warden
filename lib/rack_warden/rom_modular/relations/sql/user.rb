require_relative 'base'
require_relative '../../types'

module RackWarden
  module Rom
    module Relation
      module Sql
    
        def self.users
          Proc.new do
          #Class.new(ROM::Relation[:sql]) do
          #  register_as :users
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
              
              attribute :id, Types::Int
              attribute :username, Types::String
              attribute :email, Types::String
              attribute :encrypted_password, Types::BCryptString
              attribute :remember_token, Types::BCryptString
              attribute :remember_token_expires_at, Types::DateTime
              attribute :activated_at, Types::DateTime
              attribute :activation_code, Types::BCryptString
              attribute :password_reset_code, Types::BCryptString
              attribute :created_at, Types::DateTime
              attribute :updated_at, Types::DateTime.default { DateTime.now }
              
              primary_key :id        
            end # schema
            
            include Includes
            
            def create_table
              puts "RackWarden creating table '#{table}' in database: #{dataset}"  unless table_exists?
              dataset.db.create_table?(table) do
                # rel.schema.attributes.each do |k,v|
                #   name = k.to_sym
                #   type = v.primitive.is_a?(Dry::Types::Definition) ? v.primitive.primitive : v.primitive
                #   puts "column #{name}, #{type}"
                #   column name, type
                # end
                primary_key :id, Integer
                column :username, String
                column :email, String
                column :encrypted_password, String
                column :remember_token, String
                column :remember_token_expires_at, String
                column :activated_at, DateTime
                column :activation_code, String
                column :password_reset_code, String
                column :created_at, 'timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'
                column :updated_at, DateTime
              end
            rescue
              puts "RackWarden trouble creating '#{table}' table: #{$!}"
            end
          
          end # users relation
        
        end # def users
        
      end # Sql
    end # Relation
  end # Rom
end # RackWarden