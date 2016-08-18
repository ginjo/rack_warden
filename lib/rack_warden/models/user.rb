require 'dry-types'

module RackWarden

  class User < Entity   #Dry::Types::Struct #Struct.new(*UserKeys) do        
    attr_accessor :password, :password_confirmation
    
    # Clean this up, maybe put in base model class.
    def self.initialize_attributes(attrbts=RomContainer.relation(:users).schema.attributes.tap{|a| a.delete(:encrypted_password)})
      #puts "\nInitializing attributes for User model"
      attrbts.merge!({:encrypted_password => Types::BCryptPassword})
      attrbts.each do |k,v|
        #puts "Attribute: #{k}, #{v.primitive}"
        attribute k, v
        attr_writer k
      end
    end
    
    initialize_attributes
    
    # Update local attributes. No write to datastore.
    # def update(data)
    #   data.each do |k, v|
    #     #puts "\nUser setting data, key:#{k}, val:#{v}"
    #     self.send("#{k}=", v)
    #   end
    #   set_password
    #   self
    # rescue
    #   false
    # end
    
    def update(data)
      super(data) do
        set_password
      end
    end
    
    # def save
    #   set_password
    #   resp = repo.save_attributes self[:id], to_h
    #   self.update(resp.to_h)
    #   true
    # rescue
    #   puts "User#save ERROR: #{$!}"
    #   false
    # end
    
    def save
      super do
        set_password
      end
    end


    #####  DOMAIN SPECIFIC METHODS  #####

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