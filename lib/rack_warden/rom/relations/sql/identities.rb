require_relative 'base'
require_relative '../../types'

module RackWarden
  module Rom
    module Relations
      module Sql
    
        class Identities < Base
          register_as :identities
                              
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
            attribute :created_at, Types::DateTime
            attribute :updated_at, Types::DateTime.default { DateTime.now }
            primary_key :id
            primary_key :provider, :uid, :email
          end
                      
          def create_table
            App.logger.info "RackWarden creating table '#{table}' in database: #{dataset}" unless table_exists?
            dataset.db.create_table?(table) do
              # rel.schema.attributes.each do |k,v|
              #   name = k.to_sym
              #   type = v.primitive.is_a?(Dry::Types::Definition) ? v.primitive.primitive : v.primitive
              #   puts "column #{name}, #{type}"
              #   column name, type
              # end
              primary_key :id, Integer
              column :user_id, Integer
              column :email, String
              column :provider, String
              column :uid, String
              column :info, String
              column :credentials, String
              column :extra, String
              column :created_at, 'timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP'
              column :updated_at, DateTime
            end
          rescue
            App.logger.warn "RackWarden trouble creating '#{table}' table: #{$!}"
          end
                    
        end # def identities
        
      end # Sql
    end # Relations
  end # Rom
end # RackWarden