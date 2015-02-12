require 'rfm'

# Property & field names in dm-filemaker-adapter models must be declared lowercase, regardless of what they are in FMP.

# TODO:
# √ Fix RFM so it handles full-path yaml file spec for sax parser template :template option.
# • Fix 'read' so it handles rfm find(rec_id) types of queries.
# • Make sure 'read' handles all kinds of rfm queries (hash, array of hashes, option hashes, any combo of these).
# √ Handle rfm response, and figure out how to update dm resourse with response data. 
# √ Handle 'destroy' adapter method.
# • Fix Rfm so ruby date/time values can be pushed to fmp using the layout object (currently only works with rfm models).
#		This is also necessary to do finds with dates.
# * Find out whats up with property :writer=>false not working for mod_id and record_id.
# * Create accessors for rfm meta data, including layout meta and resultset meta.
# * Handle rfm related sets (portals).
# * Undo hard :limit setting in fmp_options method.
# √ Reload doesn't work correctly. (hmm... now it does work).
# * Move :template option to a more global place in dm-filemaker (possibly pushing it to Rfm.config ?).
# √ Create module to add methods to dm Model specifically for dm-filemaker (to be loaded with 'include DataMapper::Resource' somehow).
# √ Find place to hook in creation of properties :record_id and :mod_id. Maybe DataMapper.finalize method?
# * RFM: Make layout#count so it handles empty query (should do :all instead of :find), just like here in the dm adapter.
# √ Fix to work with dm-aggregates.
# √ Fix sort field - dm is inserting entire property object into uri (observe the query for 'model.last' to see whats going on).
# * Fix sort direction.

module DataMapper
	[Resource, Model, Adapters]
	
	# All this to tack on class and instance methods to the model/resource.
	module Resource
	  class << self
	  	alias_method :included_orig, :included
	  	def included(klass)
	  		included_orig(klass)
	  		if klass.repository.adapter.to_s[/filemaker/i]
	  			klass.instance_eval do
	  				extend repository.adapter.class::ModelMethods
		  			include repository.adapter.class::ResourceMethods
	  			end
	  		end
	  	end
	  end
	end
	
	module Model
		alias_method :finalize_orig, :finalize
		def finalize(*args)
			property :record_id, Integer, :lazy=>false
			property :mod_id, Integer, :lazy=>false
			finalize_orig
		end
	end

  module Adapters
    class FilemakerAdapter < AbstractAdapter
    
    
			###  UTILITY METHODS  ###
    
    	# Class methods extended onto model.
    	module ModelMethods
	  		def layout
	        Rfm.layout(storage_name, repository.adapter.options.symbolize_keys)
	      end
      end
    	
    	# Instance methods included in model.
    	module ResourceMethods
    		def layout
    			model.layout
    		end
    	end
  

			###  ADPTER METHODS  ###

			# Create fmp layout object from model object.
			def layout(model)
				#Rfm.layout(model.storage_name, options.symbolize_keys)   #query.repository.adapter.options.symbolize_keys)
				model.layout
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
				prms[:order].tap do |orders|
					opts[:sort_field] = orders.collect do |o|
						o.target.name
					end if orders
				end
				opts
			end
			
			# This is supposed to convert property objects to field name. Not sure if it works.
			def get_field_name(field)
				return field.field if field.respond_to? :field
				field
			end
			
			def merge_fmp_response(resource, record)
				resource.model.properties.to_a.each do |property|
					if record.key?(property.field.to_s)
						resource[property.name] = record[property.field.to_s]
					end
				end			
			end

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
				counter = 0
				resources.each do |resource|
					rslt = layout(resource.model).create(resource.attributes.delete_if {|k,v| v.to_s==''}, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					merge_fmp_response(resource, rslt[0])
					counter +=1
				end
				counter
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
			def read(query)
				#y query
				_layout = layout(query.model)
				opts = fmp_options(query)
				opts[:template] = File.expand_path('../dm-fmresultset.yml', __FILE__).to_s
				prms = fmp_query(query)
				rslt = prms.empty? ? _layout.all(opts) : _layout.find(prms, opts)
				rslt.dup.each_with_index(){|r, i| rslt[i] = r.to_h}
				rslt
			end
			
			def aggregate(query)
				_layout = layout(query.model)
				opts = fmp_options(query)
				opts[:template] = File.expand_path('../dm-fmresultset.yml', __FILE__).to_s
				prms = fmp_query(query)
				[prms.empty? ? _layout.all(:max_records=>0).foundset_count : _layout.count(prms)]
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
      	prms = fmp_attributes(attributes)
				counter = 0
				collection.each do |resource|
					rslt = layout(resource.model).edit(resource.record_id, prms, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					merge_fmp_response(resource, rslt[0])
					resource.persistence_state = DataMapper::Resource::PersistenceState::Clean.new resource
					counter +=1
				end
				counter        
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
 				counter = 0
				collection.each do |resource|
					rslt = layout(resource.model).delete(resource.record_id, :template=>File.expand_path('../dm-fmresultset.yml', __FILE__).to_s)
					counter +=1
				end
				counter
      end

			protected :fmp_query, :fmp_attributes, :fmp_options, :merge_fmp_response

		end # FilemakerAdapter
  end # Adapters
end # DataMapper
