require 'rfm'

module DataMapper
  module Adapters

    class FilemakerAdapter < AbstractAdapter
    
    # Property & field names must be declared lowercase, regardless of what they are in FMP.


    # Specific adapters extend this class and implement
    # methods for creating, reading, updating and deleting records.
    #
    # Adapters may only implement method for reading or (less common case)
    # writing. Read only adapter may be useful when one needs to work
    # with legacy data that should not be changed or web services that
    # only provide read access to data (from Wordnet and Medline to
    # Atom and RSS syndication feeds)
    #
    # Note that in case of adapters to relational databases it makes
    # sense to inherit from DataObjectsAdapter class.
			# class AbstractAdapter
			#   include DataMapper::Assertions
			#   extend DataMapper::Assertions
			#   extend Equalizer
			# 
			#   equalize :name, :options, :resource_naming_convention, :field_naming_convention
			# 
			#   # @api semipublic
			#   def self.descendants
			#     @descendants ||= DescendantSet.new
			#   end
			# 
			#   # @api private
			#   def self.inherited(descendant)
			#     descendants << descendant
			#   end
			# 
			#   # Adapter name
			#   #
			#   # @example
			#   #   adapter.name  # => :default
			#   #
			#   # Note that when you use
			#   #
			#   # DataMapper.setup(:default, 'postgres://postgres@localhost/dm_core_test')
			#   #
			#   # the adapter name is currently set to :default
			#   #
			#   # @return [Symbol]
			#   #   the adapter name
			#   #
			#   # @api semipublic
			#   attr_reader :name
			# 
			#   # Options with which adapter was set up
			#   #
			#   # @example
			#   #   adapter.options  # => { :adapter => 'yaml', :path => '/tmp' }
			#   #
			#   # @return [Hash]
			#   #   adapter configuration options
			#   #
			#   # @api semipublic
			#   attr_reader :options
			# 
			#   # A callable object returning a naming convention for model storage
			#   #
			#   # @example
			#   #   adapter.resource_naming_convention  # => Proc for model storage name
			#   #
			#   # @return [#call]
			#   #   object to return the naming convention for each model
			#   #
			#   # @api semipublic
			#   attr_accessor :resource_naming_convention
			# 
			#   # A callable object returning a naming convention for property fields
			#   #
			#   # @example
			#   #   adapter.field_naming_convention  # => Proc for field name
			#   #
			#   # @return [#call]
			#   #   object to return the naming convention for each field
			#   #
			#   # @api semipublic
			#   attr_accessor :field_naming_convention

      # Persists one or many new resources
      #
      # @example
      #   adapter.create(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Enumerable<Resource>] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        raise NotImplementedError, "#{self.class}#create not implemented"
      end

      # Reads one or many resources from a datastore
      #
      # @example
      #   adapter.read(query)  # => [ { 'name' => 'Dan Kubb' } ]
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Query] query
      #   the query to match resources in the datastore
      #
      # @return [Enumerable<Hash>]
      #   an array of hashes to become resources
      #
      # @api semipublic
			# def read(query)
			#   raise NotImplementedError, "#{self.class}#read not implemented"
			# end
			#
			### Uses Rfm::Connection
			# def read(query)
			# 	dm = query.model.dm
			# 	#layout = Rfm.layout(query.model.layout_name, query.repository.adapter.options.symbolize_keys)
			# 	#query.model.dm[:layout] = layout
			# 
			# 	params = query.options
			# 	config = query.repository.adapter.options.symbolize_keys
			# 	layout_name = query.model.layout_name
			# 	dm[:params_before] = params
			# 	dm[:config] = config
			# 	dm[:layout_name] = layout_name
			# 	
			# 	prms = params.dup
			# 	opts = {}
			# 	opts[:skip_records] = prms.delete(:offset) if prms[:offset]
			# 	opts[:max_records] = prms.delete(:limit) if prms[:limit]
			# 	opts[:sort_field] = prms.delete(:order) if prms[:order]
			# 	dm[:opts] = opts
			# 
			# 	#prms = {prms.keys[0].name => prms.values[0]} if prms.size ==1 && !prms.keys[0].is_a?(Symbol)
			# 	prms.dup.each {|k,v| prms[k.name]=prms.delete(k) if !k.is_a?(String) && !k.is_a?(Symbol)}
			# 	prms.merge!({"-db" => config[:database], "-lay" => layout_name})
			# 	dm[:prms_after] = prms
			# 
			# 	connection = Rfm::Connection.new('-find', prms, opts, config)
			# 	dm[:connection] = connection
			# 	rslt = connection.parse(nil, Rfm::Resultset.new)
			# 	dm[:result1] = rslt
			# 	rslt.dup.each_with_index(){|r, i| rslt[i] = r.to_h}
			# 	dm[:result2] = rslt
			# 	rslt
			# 	#Array(layout.any).to_a.flatten
			# end
			#
			### Uses Rfm::Layout
			def read(query)
				dm = query.model.dm
				dm[:query] = query

				_layout = layout(query)
				
				prms = query.options
				opts = {}
				prms[:offset].tap {|x| opts[:skip_records] = x if x}
				prms[:limit].tap {|x| opts[:max_records] = x if x}
				prms[:order].tap {|x| opts[:sort_field] = x if x}

				# replaces key-field object with key-field name in prms
				#prms.dup.each {|k,v|  (prms[k.name]=prms.delete(k); puts prms.inspect) if !(k.is_a?(::String) || k.is_a?(::Symbol))}
				
				# translates property name to field name, if :field is defined on property
				#prms.dup.each {|k,v| (prms[translate_field_name(query,k)]=prms.delete(k); puts prms.inspect) if translate_field_name(query,k)}
				
				prms = Hash.new.tap(){|h| query.conditions.operands.each {|k,v| h.merge!({k.subject.field.to_s => k.loaded_value})} }
				
				rslt = _layout.find(prms, opts)
				rslt.dup.each_with_index(){|r, i| rslt[i] = r.to_h}
				rslt
			end
			
			def layout(query)
				Rfm.layout(query.model.storage_name, query.repository.adapter.options.symbolize_keys)
			end
			
			def translate_field_name(query, name)
				query.instance_variable_get(:@properties)[name].tap{|_name| _name.field if _name}
			end
			

      # Updates one or many existing resources
      #
      # @example
      #   adapter.update(attributes, collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        raise NotImplementedError, "#{self.class}#update not implemented"
      end

      # Deletes one or many existing resources
      #
      # @example
      #   adapter.delete(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end

			#   # Create a Query object or subclass.
			#   #
			#   # Alter this method if you'd like to return an adapter specific Query subclass.
			#   #
			#   # @param [Repository] repository
			#   #   the Repository to retrieve results from
			#   # @param [Model] model
			#   #   the Model to retrieve results from
			#   # @param [Hash] options
			#   #   the conditions and scope
			#   #
			#   # @return [Query]
			#   #
			#   # @api semipublic
			#   #--
			#   # TODO: DataObjects::Connection.create_command style magic (Adapter)::Query?
			#   def new_query(repository, model, options = {})
			#     Query.new(repository, model, options)
			#   end

			# protected
			# 
			# # Set the serial value of the Resource
			# #
			# # @param [Resource] resource
			# #   the resource to set the serial property in
			# # @param [Integer] next_id
			# #   the identifier to set in the resource
			# #
			# # @return [undefined]
			# #
			# # @api semipublic
			# def initialize_serial(resource, next_id)
			#   return unless serial = resource.model.serial(name)
			#   return unless serial.get!(resource).nil?
			#   serial.set!(resource, next_id)
			# 
			#   # TODO: replace above with this, once
			#   # specs can handle random, non-sequential ids
			#   #serial.set!(resource, rand(2**32))
			# end
			# 
			# # Translate the attributes into a Hash with the field as the key
			# #
			# # @example
			# #   attributes = { User.properties[:name] => 'Dan Kubb' }
			# #   adapter.attributes_as_fields(attributes)  # => { 'name' => 'Dan Kubb' }
			# #
			# # @param [Hash] attributes
			# #   the attributes with the Property as the key
			# #
			# # @return [Hash]
			# #   the attributes with the Property#field as the key
			# #
			# # @api semipublic
			# def attributes_as_fields(attributes)
			#   Hash[ attributes.map { |property, value| [ property.field, property.dump(value) ] } ]
			# end
			# 
			# private
			# 
			# # Initialize an AbstractAdapter instance
			# #
			# # @param [Symbol] name
			# #   the adapter repository name
			# # @param [Hash] options
			# #   the adapter configuration options
			# #
			# # @return [undefined]
			# #
			# # @api semipublic
			# def initialize(name, options)
			#   @name                       = name
			#   @options                    = options.dup.freeze
			#   @resource_naming_convention = NamingConventions::Resource::UnderscoredAndPluralized
			#   @field_naming_convention    = NamingConventions::Field::Underscored
			# end


		end # FilemakerAdapter
  end
end
