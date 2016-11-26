module RackWarden
  module Rom
    module Repositories
      class Base < ROM::Repository::Root
      
        attr_accessor :entity
        
        # Allow custom repo class to be subclassed from this one.
        # Clears relations & roots in interim annonymous class.
        def self.[](relation_root)
          cl = super
          cl.relations.clear
          cl.relations(relation_root)
          cl.root(relation_root)
          cl
        end
              
        # def root
        #   entity ? super.as(entity) : super
        # end
        
        def initialize(_container, _entity=nil)
          _container = _container.is_a?(Proc) ? _container.call : _container
          App.logger.debug "RW repo #{self} initializing with rom-container: #{_container}, entity: #{_entity}"
          super(_container)
          @entity = _entity
          self
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
                
        def query(*args)
          root.query(*args)
        end
        
        # TODO: I think rom-sql has automatic :by_pk methods. Check that out.
        
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