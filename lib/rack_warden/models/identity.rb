module RackWarden

  # TODO: Make sure OmniAuth classes are loaded before loading auth_hash yaml.

  class Identity < Entity  #Dry::Types::Struct
    
    # attribute :id, Types::Int
    # attribute :user_id, Types::String
    # attribute :email, Types::String
    # attribute :provider, Types::String
    # attribute :uid, Types::String
    # attribute :info, Types::FromYaml
    # attribute :credentials, Types::FromYaml
    # attribute :extra, Types::FromYaml
    # attribute :created_at, Types::DateTime
    # #attribute :auth_hash, Types::FromYaml
    
    # Use schema attributes from base relation, put overrides in the block.
    initialize_attributes(RomContainer.relation(:identities).schema.attributes) do
      {
      :info => Types::FromYaml,
      :credentials => Types::FromYaml,
      :extra => Types::FromYaml
      }
    end
    
    def is_admin?
      info.is_admin
    end
    
    def guid
      "#{provider}-#{uid}-#{email}"
    end
    
    def user
      _user = RackWarden::UserRepo.locate_or_create_from_identity(self)
      self.user_id = _user.id if (_user.is_a?(RackWarden::User) && user_id.to_s.empty?)
      _user
    end
    
    
    #####  From old RackWarden::Identity  #####
    
    #extend Forwardable
    
    
    # TODO: This should really not be necessary any more.
    attr_accessor :auth_hash  #, :user_id
    #def_delegators :auth_hash, :uid, :provider, :info, :credentials, :extra, :[]
    
    # def self.locate_or_create(identifier) # identifier should be auth_hash
    #   #puts "Identity.locate_or_create: #{identifier.class}"
    #   identity = (locate(identifier) || new(identifier))
    # end
    
    # def self.new(auth_hash)
    #   #puts "Identity.new: #{auth_hash.class}"
    #   identity = super(auth_hash) if (auth_hash['uid'] && auth_hash['provider'])
    #   identity.save if identity
    #   identity
    # end
    
    # def self.write
    #   File.open('identities.yml', 'w') { |f|
    #     f.puts STORE.to_yaml
    #   }
    # end
    
    # def self.locate(identifier) # id or auth_hash
    #   #puts "Identity.locate: #{identifier.class} \"#{identifier}\""
    #   auth_hash = (identifier.respond_to?(:uid) || identifier.is_a?(Hash)) ? identifier : {}
    #   uid = (auth_hash[:uid] || auth_hash['uid'] || auth_hash.uid || identifier) rescue identifier
    #   identity = STORE.find{|i| i.uid.to_s == uid.to_s}
    #   if identity && auth_hash['provider'] && auth_hash['uid']
    #     identity.auth_hash = auth_hash
    #   end
    #   #puts "Identity.locate found: #{identity.class}"
    #   identity
    # end
    
    # def self.locate(auth_hash) # id or auth_hash or query hash
    #   by_guid(auth_hash.provider, auth_hash.uid, auth_hash.info.email)
    # end
    
    # ### For RackWarden
    # def self.get(*args)
    #   locate(*args)
    # end
    
    # def id
    #   uid
    # end

    # # TODO: This should really not be necessary any more.    
    # def initialize(_auth_hash={})
    #   @auth_hash = _auth_hash
    #   self
    # end
  
    def name; info['name']; end
    #def email; info['email']; end
    
    def username; name; end
  
    
    
  end # Identity


end # RackWarden