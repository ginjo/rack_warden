module RackWarden

  class Entity < Dry::Types::Struct
  
    # NOTE: dry-struct.new does most of the work in setting up the struct & populating attributes.
    #       The #initialize method doesn't really do anything.
  
    constructor_type(:schema) #I think this makes it less strict (allows missing keys).
        
    # Send class methods to UserRepo.
    def self.method_missing(*args)
      begin
        repo.send(*args)
      #rescue NoMethodError
      #  super(*args)
      end
    end
    
    # Load attributes from somewhere else.
    #   Pass param of attrbibutes from somewhere else (like schema)
    #   Pass a block of extra attributes, as a hash, to be (destructively) merged.
    # Example:
    # initialize_attributes(RomContainer.relation(:users).schema.attributes.tap{|a| a.delete(:encrypted_password)}) do
    #   {:encrypted_password => Types::BCryptString}
    # end
    def self.initialize_attributes(_attributes = Hash.new)
      #puts "\nInitializing attributes for User model"
      _extra = block_given? ? yield : Hash.new
      _attributes.merge!(_extra)
      _attributes.each do |k,v|
        #puts "Attribute: #{k}, #{v.primitive}"
        attribute k, v
        attr_writer k
      end
    end
    

            
    def self.repo
      @repo ||= eval("#{name}RepoClass").new(RomContainer)
    end

    # Needed to handle extra non-db attributes,
    # since the dry-struct deletes them within its own 'new'.
    # All of dry-structs magic appears to happen at the class.new method (in C code probably).
    def self.new(dat={})
      # Conversion to hash might be breaking identity-stored-as-omniauath-authhash.
      #hash = hash.to_h
      new_instance = super(dat)
      extra_attrs = dat.to_h.dup.delete_if {|k,v| new_instance.instance_variables.include?(:"@#{k}")}
      new_instance.update(extra_attrs)
      new_instance
    end


    def repo; self.class.repo; end
    
    # Update local attributes. No write to datastore.
    # TODO: Does this need a different name, like 'update_local_attributes'?
    def update(data) # and run passed block if successful
      data.each do |k, v|
        #puts "\nUser setting data, key:#{k}, val:#{v}"
        self.send("#{k}=", v)
      end
      yield(data) if block_given?
      self
    rescue
      false
    end
    
    # TODO: This is shomehow breaking the toyaml constructors.
    # TODO: I think the save & save! logic is wrong.
    #       Find out where each is used here.
    def save
      #set_password
      yield if block_given?
      resp = repo.save_attributes self[:id], to_h
      self.update(resp.to_h)
      true
    end
    
    def save!
      save
    rescue
      App.logger.debug "RW #{self.class.name}#save ERROR: #{$!}"
      false
    end
    
    def delete
      repo.delete(self[:id])
    end
    
  end # Entity
end # RackWarden