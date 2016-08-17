module RackWarden

  class User < Dry::Types::Struct #Struct.new(*UserKeys) do
    constructor_type(:schema) #I think this makes it less strict (allows missing keys).
    
    attr_accessor :password, :password_confirmation

    def self.initialize_attributes(attrbts=RomContainer.relation(:users).schema.attributes.tap{|a| a.delete(:encrypted_password)})
      #puts "\nInitializing attributes for User model"
      attrbts.merge!({:encrypted_password => Types::BCryptPassword})
      attrbts.each do |k,v|
        #puts "Attribute: #{k}, #{v.primitive}"
        attribute k, v
        attr_writer k
      end
    end
            
    def self.repo
      @repo ||= UserRepoClass.new(RomContainer)
    end
        
    def repo; self.class.repo; end
    
    # Shortcut method for repo, to get users relation as User.
    # Not really necessary, just an example of sugar.
    def self.get
      repo.users.as(self)
    end
    
    # Needed to handle extra non-db attributes,
    # since the dry-struct deletes them within its own 'new'.
    # All of dry-structs magic appears to happen at the class.new method (in C code probably).
    def self.new(hash={})
      new_user = super(hash)
      extra_attrs = hash.dup.delete_if {|k,v| new_user.instance_variables.include?(:"@#{k}")}
      new_user.update(extra_attrs)
      new_user
    end
    
    initialize_attributes
    
    
    ## IMPORTANT: This method does not get called until AFTER
    ## the '.new' method populates the attributes.    
    # def initialize(*args)
    #   #update(data.to_h)
    #   #super(*args)
    #   set_password
    #   self
    # end
    
    # Update local attributes. No write to datastore.
    def update(data)
      data.each do |k, v|
        #puts "\nUser setting data, key:#{k}, val:#{v}"
        self.send("#{k}=", v)
      end
      set_password
      self
    rescue
      false
    end
    
    def save
      set_password
      resp = repo.save_attributes self[:id], to_h
      self.update(resp.to_h)
      true
    rescue
      puts "User#save ERROR: #{$!}"
      false
    end
    
    def delete
      repo.delete(self[:id])
    end
    
    # The dry-struct only applies Types at construction.
    def encrypted_password=(pswd)
      @encrypted_password = Types::BCryptPassword[pswd]
    end
    
    #private :'encrypted_password='
    
    def set_password
      #puts "\nSetting User password with User:"
      #puts self.to_yaml
      if (@password == @password_confirmation && !@password.to_s.empty?)
        self.encrypted_password = @password
        @password, @password_confirmation = nil, nil
      end
      true
    end
    
    def authenticate(pswd)
      encrypted_password == pswd
    end
    
  end # User model
end # RackWarden