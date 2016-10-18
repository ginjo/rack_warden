module RackWarden
  module Rom
    module Entities

      #class Entity < Dry::Types::Struct
      class Base < Dry::Struct
      
        class << self; attr_accessor :repository; end
        
        def repository; self.class.repository; end
        
        def self.[](repo)
          # Need interim subclass to set repo with.
          interim_class = Class.new(self)
          interim_class.repository = repo
          App.logger.debug "RW set repository for class #{interim_class} to #{repo}"
          # Return interim_class to entity class setup. The new entity class inherits from interim_class
          interim_class
        end
        
        # This helps set the repo of the entity from the interim_class
        def self.inherited(base)
          # Dry::Types::ClassInterface has a 'inherited' method,
          # so this 'super' is absolutely necessary, or that method will be clobbered.
          super
          base.repository = @repository
        end
        
        def self.repository
          case
            when @repository.is_a?(String); eval(@repository)
            when @repository.is_a?(Symbol); eval(@repository.to_s.capitalize)
            when @repository.is_a?(Class); @repository
            when @repository.is_a?(ROM::Repository); @repository
            #else @repository
          end
        end
        
      
        # NOTE: dry-struct.new does most of the work in setting up the struct & populating attributes.
        #       The #initialize method doesn't really do anything.
      
        constructor_type(:schema) #I think this makes it less strict (allows missing keys).
            
        # Send class methods to UserRepo.
        def self.method_missing(*args)
          begin
            repository.send(*args)
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
          _extra = block_given? ? yield : Hash.new
          _attributes.merge!(_extra)
          App.logger.debug "RW initializing attributes for model: #{self}, ancestors: #{self.ancestors}, attributes: #{_attributes}"
          _attributes.each do |k,v|
            App.logger.debug "RW initializing attribute name: #{k}, primitive: #{v}"
            attribute k, v
            attr_writer k
          end
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
          resp = repository.save_attributes self[:id], to_h
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
          repository.delete(self[:id])
        end
    
      end # Base
    end # Entities
  end # Rom
end # RackWarden