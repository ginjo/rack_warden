module RackWarden
  ###  OMNIAUTH CODE  ###
  #

  #
  class Identity
    extend Forwardable
    
    STORE=[]
    File.open('identities.yml', 'a').close
    
    attr_accessor :auth_hash, :user_id
    def_delegators :auth_hash, :uid, :provider, :info, :credentials, :extra, :[]
    
    def self.locate_or_new(identifier) # or auth_hash
      #puts "Identity.locate_or_new: #{identifier.class}"
      identity = (locate(identifier) || new(identifier))
    end
    
    def self.new(auth_hash)
      #puts "Identity.new: #{auth_hash.class}"
      identity = super(auth_hash) if (auth_hash['uid'] && auth_hash['provider'])
      if identity
        #puts "Identity.new SUCCEEDED"
        (STORE << identity) &&
        write
      else
        #puts "Identity.new FAILED"
      end
      identity
    end
    
    def self.write
      File.open('identities.yml', 'w') { |f|
        f.puts STORE.to_yaml
      }
    end
      
    
    def self.locate(identifier) # id or auth_hash
      #puts "Identity.locate: #{identifier.class}"
      auth_hash = (identifier.respond_to?(:uid) || identifier.is_a?(Hash)) ? identifier : {}
      uid = auth_hash['uid'] || identifier.to_s
      identity = STORE.find{|i| i.uid.to_s == uid.to_s}
      if identity && auth_hash['provider'] && auth_hash['uid']
        identity.auth_hash = auth_hash
      end
      #puts "Identity.locate found: #{identity.class}"
      identity
    end
    
    ### For RackWarden
    def self.get(*args)
      locate(*args)
    end
    
    def id
      uid
    end
    
    def initialize(_auth_hash={})
      @auth_hash = _auth_hash
      self
    end
  
    def name; info['name']; end
    def email; info['email']; end
    
    def username; name; end
  
    
  end # Identity
  Identity::STORE.replace(YAML.load_file('identities.yml') || [])
  ###  END OMNIAUTH CODE  ###
  
end # RackWarden

