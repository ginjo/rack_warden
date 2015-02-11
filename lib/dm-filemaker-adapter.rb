require 'rfm'
require 'forwardable'

module DataMapper

	module Resource
	  class << self
	  	alias_method :included_orig, :included
	  	def included(klass)
	  		included_orig(klass)
	  		if klass.repository.adapter.to_s[/filemaker/i]
	  			klass.instance_eval do
	  				puts "#{klass.inspect}.instance_eval"
	  				extend Forwardable
		  			def_delegators 'repository.adapter', :layout
		  			include repository.adapter.class::ResourceMethods
	  			
	  			end
	  		end
	  	end
	  end
	end

  module Adapters

    class FilemakerAdapter < AbstractAdapter
    
    	module ModelMethods
    		repository.adapter
    	end
    	
    	# Instance method module will be included in Model, giving instance methods to each resource.
    	module ResourceMethods
    		def layout
    			model.layout
    		end
    	end
    	
#     	def self.extended(*args)
#     		puts "FilemakerAdapter-class Including FilemakerAdapter::ResourceMethods in #{args}"
#     		#base.include ResourceMethods
#     		super
#     	end
    
    	# Storage space to attach instance objects to model class, for experimentation & testing only!
			#     	class << self
			#     		attr_accessor :inst
			#     	end
			#     	@inst = {}
    
	    # Property & field names must be declared lowercase, regardless of what they are in FMP.
	    
	    # TODO:
	    # √ Fix RFM so it handles full-path yaml file spec for sax parser template :template option.
	    # • Fix 'read' so it handles rfm find(rec_id) types of queries.
	    # • Make sure 'read' handles all kinds of rfm queries (hash, array of hashes, option hashes, any combo of these).
	    # √ Handle rfm response, and figure out how to update dm resourse with response data. 
	    # √ Handle 'destroy' adapter method.
	    # • Fix Rfm so ruby date/time values can be pushed to fmp using the layout object (currently only works with rfm models).
	    # * Find out whats up with property :writer=>false not working for mod_id and record_id.
	    # * Create accessors for rfm meta data, including layout meta.
	    # * Handle rfm related sets (portals).
	    # * Undo hard :limit setting in fmp_options method.
	    # √ Reload doesn't work correctly. (hmm... now it does work).
	    # * Move :template option to a more global place in dm-filemaker (possibly pushing it to Rfm.config ?).
	    # * Create module to add methods to dm Model specifically for dm-filemaker (to be loaded with 'include DataMapper::Resource' somehow).

    	# Note that all methods defined in adapter class will also be extended onto Model,
    	# so you might want to make some of them private.
    	

			# Create fmp layout object from model object.
			def layout(model)
				Rfm.layout(model.storage_name, options.symbolize_keys)   #query.repository.adapter.options.symbolize_keys)
			end
			
			# Convert dm query object to fmp query params (hash)
			def fmp_query(query)
				Hash.new.tap(){|h| query.conditions.operands.each {|k,v| h.merge!({k.subject.field.to_s => k.loaded_value}) if k.loaded_value.to_s!=''} }
			end
			
			# Convert dm attributes hash to regular hash
			def fmp_attributes(attributes)
				Hash.new.tap(){|h| attributes.each {|k,v| h.merge!({k.field.to_s => v})} }
			end
			
			# Get fmp options hash from query
			def fmp_options(query)
				prms = query.options
				opts = {}
				prms[:offset].tap {|x| opts[:skip_records] = x if x}
				prms[:limit].tap {|x| opts[:max_records] = x || 100}
				prms[:order].tap {|x| opts[:sort_field] = x if x}
				opts
			end
			
			def merge_fmp_response(resource, record)
				resource.model.properties.to_a.each do |property|
					if record.key?(property.field.to_s)
						resource[property.name] = record[property.field.to_s]
					end
				end			
			end

			### From datamapper adapter source on github.
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
      	#self.class.inst[:self] = self
      	#self.class.inst[:resour] = resources
				counter = 0
				resources.each do |resource|
					rslt = layout(resource.model).create(resource.attributes.delete_if {|k,v| v.to_s==''}, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					merge_fmp_response(resource, rslt[0])
					counter +=1
				end
				counter
				
        #raise NotImplementedError, "#{self.class}#create not implemented"
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
				#dm = query.model.dm
				#dm[:query] = query

				_layout = layout(query.model)
				
				opts = fmp_options(query)
				
				opts[:template] = File.expand_path('../dm-fmresultset.yml', __FILE__).to_s

				prms = fmp_query(query)
				
				#dm[:opts] = opts
				#dm[:prms] = prms
				
				rslt = prms.empty? ? _layout.all(opts) : _layout.find(prms, opts)
				#dm[:rslt] = rslt.dup
				rslt.dup.each_with_index(){|r, i| rslt[i] = r.to_h}
				rslt
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
      	#y :attributes=>attributes, :collection=>collection
      	prms = fmp_attributes(attributes)
				counter = 0
				collection.each do |resource|
					rslt = layout(resource.model).edit(resource.record_id, prms, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					#y ['Model#update RFM result', rslt]
					merge_fmp_response(resource, rslt[0])
					resource.persistence_state = DataMapper::Resource::PersistenceState::Clean.new resource
					counter +=1
				end
				counter        
        #raise NotImplementedError, "#{self.class}#update not implemented"
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
      	#y collection
 				counter = 0
				collection.each do |resource|
					rslt = layout(resource.model).delete(resource.record_id, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					#y ['Model#delete RFM result', rslt]
					#merge_fmp_response(resource, rslt[0])
					#resource.persistence_state = DataMapper::Resource::PersistenceState::Clean.new resource
					counter +=1
				end
				counter
        #raise NotImplementedError, "#{self.class}#delete not implemented"
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

			#protected :fmp_query, :fmp_attributes, :fmp_options, :merge_fmp_response

		end # FilemakerAdapter
  end
end
