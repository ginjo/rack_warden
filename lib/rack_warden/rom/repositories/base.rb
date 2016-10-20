module RackWarden
  module Rom
    module Repositories
      class Base < ROM::Repository::Root
      
        attr_accessor :entity
      
        # Entities can't be resolved until they are set up - which happens after repositories.
        def entity
          case
            when @entity.is_a?(String); eval(@entity)
            when @entity.is_a?(Symbol); instance_eval{ Entities.const_get(@entity.to_s.capitalize) }
            when @entity.is_a?(Proc); @entity.call
            else @entity
          end
        end
        
        def initialize(_container, _entity=nil)
          App.logger.info "RW #{self} initializing with rom-container: #{_container}, entity: #{_entity}"

          @entity = _entity
          super(_container)
          #self
        end

        # Makes it easier to save changed models.
        def save_attributes(_id, _attrs)
          App.logger.debug "RW Repository(#{self})#save_attributes (id: #{_id})"
          #App.logger.debug _attrs.to_yaml
          _attrs.delete_if {|k,v| v==nil} unless _id
          _changeset = changeset(_id, _attrs)
          #App.logger.debug "RW Repository changeset"
          #App.logger.debug _changeset.to_yaml
          case
          when _changeset.update?
            App.logger.debug "RW Repository#save_attributes update"
            App.logger.debug "RW Repository _changeset.diff"
            App.logger.debug _changeset.diff  #.to_yaml
            saved = update(_id, _changeset)
          when _changeset.create?
            App.logger.debug "RW Repository#save_attributes create"
            saved = create(_changeset)
          end
          saved
        end
        
        
        
        ###  NEWLY ATSTRACTED METHODS  ###
        
        #   def identities
        #     super.as(Identity)
        #   end

        def root
          super.as(entity)
        end
        
        # def rel
        #   puts "RW #{self} sending #{root.options[:name]}"
        #   #send(root.options[:name])
        #   root
        # end
                
        def query(*args)
          root.query(*args)
        end
        
        # I think rom-sql already does this as :by_pk,
        # but how does it work?
        # def by_primary_key(provider, uid, email)
        #   identities.where(uid: uid, provider: provider, email: email).one
        # end
        
        def ids
          root.ids
        end
        
        def by_id(_id)
          root.by_id(_id).one
        end
        alias_method :get, :by_id
    
        def first
          root.first
        end
            
        def last
          root.last.one
        end
        
        # An 'all' method really should not be here,
        # since when the table gets large, it won't make any sense.
        def all
          root.to_a
        end
        
        def count
          root.count
        end        
        
      end # Base
    end # Repositories
  end # Rom
end # RackWarden