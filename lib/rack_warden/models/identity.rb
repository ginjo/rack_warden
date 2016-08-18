module RackWarden

  # TODO: Make sure OmniAuth classes are loaded before loading auth_hash yaml.

  class Identity < Entity  #Dry::Types::Struct
    
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
    
    def guid
      "#{provider}-#{uid}-#{email}"
    end
    
  end # Identity


end # RackWarden