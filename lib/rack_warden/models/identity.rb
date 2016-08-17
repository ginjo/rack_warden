module RackWarden

  # TODO: Make sure OmniAuth classes are loaded before loading auth_hash yaml.
  # TODO: Use this as base, when you build rom into rack_warden.
  puts "LOADING Identity"
  class Identity < Dry::Types::Struct
    constructor_type(:schema) # relaxes strickness of missing keys & values
    
    attribute :id, Types::Int
    attribute :user_id, Types::String
    attribute :email, Types::String
    attribute :provider, Types::String
    attribute :uid, Types::String
    attribute :info, Types::FromYaml
    attribute :credentials, Types::FromYaml
    attribute :extra, Types::FromYaml
    attribute :created_at, Types::DateTime
    #attribute :auth_hash, Types::FromYaml
    
    def is_admin?
      info.is_admin
    end
  end


end # RackWarden