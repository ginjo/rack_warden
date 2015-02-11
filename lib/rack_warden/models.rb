# Setup the database connection, schema, etc.
module RackWarden
  module Model
  	
  	# Any modles used by RackWarden should inherit from Base.
  	class Base
			@descendents, @field_map = [], {}
			
  		class << self
	  		attr_accessor :descendents, :field_map
	  		
	  		def inherited(model)
	  			descendents << model
	  			model.instance_eval do
		  			App.logger.debug "RW Model::Base.inherited by #{model}"
				    include DataMapper::Resource
				    include BCrypt
				    def self.default_repository_name; App.repository_name; end
			    end
		    end
		    
		    def remap_fields(mapping=field_map)
		    	field_map.each do |k,v|
		    		properties[k.to_symbol].instance_variable_set :@field, v.to_s
		    	end
		    end
	    
	    end # self
  	end # Base

		# Load models, setup database adapter, setup db repository.
	  def self.initialize_models
	  
		  # Select existing datamapper repository, create a new one, or create a default.
		  begin
		  	DataMapper.repository(App.repository_name).adapter
		  	if not App.database_config.to_s.downcase[/auto|existing/]
		  		App.repository_name = :rack_warden
		  		DataMapper.setup(App.repository_name, get_database_config)
		  	end
		  rescue DataMapper::RepositoryNotSetupError
		  	DataMapper.setup(App.repository_name, get_database_config)
		  end
		  
		  # Careful! This could expose sensitive db login info in the log files.
		  App.logger.debug "RW RackWarden::Model.initialize_models selected DataMapper repository: #{DataMapper.repository(App.repository_name).adapter.inspect}"
		  
		  # Careful! This could expose sensitive db login info in the log files.
		  App.logger.warn "RW RackWarden::Model.initialize_models using DataMapper repository: #{DataMapper.repository(App.repository_name).adapter.options.dup.tap{|o| o.delete(:password); o.delete('password')}.inspect}"
		
			App.logger.warn "RW RackWarden::Model.initialize_models DataMapper logging to: #{DataMapper.logger.log} (level #{DataMapper.logger.level})"
		
		
			# Load all models.
		  App.logger.debug "RW RackWarden::Model.initialize_models requiring model files in #{File.join(File.dirname(__FILE__), 'models/*')}"
		  Dir.glob(File.join(File.dirname(__FILE__), 'models/*')).each {|f| require f}
			
			
			Base.descendents.each do |d|
				# Remap fields with supplied hash
				d.remap_fields
			
				# DataMapper finalize
			  App.logger.debug "RW RackWarden::Model.initialize_models DataMapper.finalize"
			  # Tell DataMapper the models are done being defined
			  d.finalize
			
				# DataMapper auto upgrade.
			  App.logger.warn "RW RackWarden::Model.initialize_models User.auto_upgrade!"
			  # Update the database to match the properties of User.
			  #DataMapper.auto_upgrade!
			  d.auto_upgrade!
		  end
	  end
	  
	  
	  # Best guess at framework database settings.
	  def self.get_database_config
	  	#App.logger.debug ActiveRecord::Base.configurations[(RackWarden::App.environment || :development).to_s].to_yaml
	    conf = case
	    when App.database_config.to_s.downcase == 'memory'; "sqlite3::memory:?cache=shared"
	    when App.database_config.to_s.downcase == 'file'; "sqlite3:///#{Dir.pwd}/rack_warden.sqlite3.db"
	    when App.database_config.to_s.downcase == 'auto';
		    (ActiveRecord::Base.connection_config rescue nil) ||
		    (ActiveRecord::Base.configurations rescue nil) ||
		    #(DataMapper.repository(App.repository_name).adapter[:options] rescue nil) ||
	    	App.database_default
	    when App.database_config; App.database_config
	    else App.database_default
	    end
	    #... sort out environment HERE
	    rslt = conf[(RackWarden::App.environment || :development).to_s] || conf
	    rslt[:adapter] = 'mysql' if rslt && [:adapter]=='mysql2'
	    App.logger.debug "RW RackWarden::Model.get_database_config rslt: #{rslt.inspect}"
	    return rslt
	  end
	  
	  initialize_models
  
	end # Model
  
end # RackWarden