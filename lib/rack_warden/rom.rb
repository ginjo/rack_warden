require 'rom-repository'
require 'rom-sql'


module RackWarden

  DbPath = File.join(Dir.getwd, 'rack_warden.sqlite3.db')


  #####  TYPES  #####

  module Types
    include Dry::Types.module
    
    def self.ensure_bcrypt(dat)
      return if dat.to_s.empty?
      begin
        BCrypt::Password.new(dat)
      rescue BCrypt::Errors::InvalidHash
        BCrypt::Password.create(dat)
      end
    end
        
    BCryptPassword = Dry::Types::Definition.new(BCrypt::Password).constructor do |dat|
      #puts "\nBCryptPassword constructor with data: #{dat}"
      ensure_bcrypt(dat)
    end
    
    BCryptString = Dry::Types::Definition.new(String).constructor do |dat|
      #puts "\nBCryptString constructor with data: #{dat}"
      ensure_bcrypt(dat).to_s
    end
    
    ToYaml = Dry::Types::Definition.new(String).constructor do |dat|
      #puts "\nToYaml constructor with data: #{dat.to_yaml}"
      if dat.is_a?(::String)
        dat
      else
        dat.to_yaml
      end
    end
    
    FromYaml = Dry::Types::Definition.new(Hash).constructor do |dat|
      #puts "FromYaml constructor with data: #{dat}"
      YAML.load(dat.to_s)
    end
    
    ToMarshal = Dry::Types::Definition.new(String).constructor do |dat|
      App.logger.debug "RW Rom Types::ToMarshal constructor with data: #{dat.to_yaml}"
      if dat.is_a?(::String)
        dat
      else
        Marshal.dump(dat)
      end
    end
    
    FromMarshal = Dry::Types::Definition.new(Hash).constructor do |dat|
      App.logger.debug "RW Rom Types::FromMarshal constructor with data: #{dat}"
      Marshal.load(dat.to_s)
    end
    
  end # Types
  
  
  
  #####  COMMON  #####

  module RelationIncludes
    ### Hide database-specific calls behind generic methods
    def query(*conditions)
      where(*conditions)
      # This would be 'find(conditions)' for rom-fmp
    end
    
    def by_id(_id)
      where(:id => _id)
    end
  
    # collect a list of all user ids
    def ids
      pluck(:id)
    end
    
    # Because built-in 'last' method can only return a hash ('as' doesn't work).
    def last
      order(:id).reverse.limit(1)
    end   
  end


  #####  CONFIG & RELATIONS  #####

  # For RackWarden, you will likely have a separate one of these for each adapter.
  RomConfig = ROM::Configuration.new(:sql, "sqlite://#{DbPath}") do |config|
    types = ROM::Types
        
    users_rel = config.relation :users do
      #dataset :rack_warden_users     
      schema(:rack_warden_users) do
        
        # Macros for default values. The password functions
        # really belong in the relation or model, not in the schema.
        #UUID = types::String.default { SecureRandom.uuid }
        #attribute :id, UUID
        #pswd = types::String.default {SecureRandom.hex}
        #bcrypt = types::String.default {|r,v| BCrypt::Password.create(r.instance_variable_get :@password)}
        
        # TODO: I dont think the activation, remember, reset codes need to be bcrypt,
        #       can probably just be SecureRandom strings.
        
        attribute :id, types::Int
        attribute :username, types::String
        attribute :email, types::String
        attribute :encrypted_password, Types::BCryptString
        attribute :remember_token, Types::BCryptString
        attribute :remember_token_expires_at, types::DateTime
        attribute :activated_at, types::DateTime
        attribute :activation_code, Types::BCryptString
        attribute :password_reset_code, Types::BCryptString
        
        primary_key :id        
      end # schema
      
      include RelationIncludes
    
    end # users_rel
    
    
    identities_rel = config.relation :identities do
      #dataset :rack_warden_identities    
      schema(:rack_warden_identities) do
        attribute :id, Types::Int
        attribute :user_id, Types::Int
        attribute :email, Types::String
        attribute :provider, Types::String
        attribute :uid, Types::String
        attribute :info, Types::ToYaml
        attribute :credentials, Types::ToYaml
        attribute :extra, Types::ToYaml
        attribute :created_at, Types::DateTime.default { DateTime.now }
        primary_key :id
        primary_key :provider, :uid, :email
      end
      
      include RelationIncludes
      
      #   # Get a single record by uique combo of provider-uid. Email is no longer used.
      #   # Args can be passed as all 2 or string concat of all 2 (separated by dash "-").
      #   # TODO: Use something other than dash, it will eventually conflict with data.
      #   # TODO: This should probably be in repo, maybe?
      #   #def by_guid(_provider, _uid=nil, _email=nil)
      #   def by_guid(_provider, _uid=nil, _email=nil)
      #     unless _uid && _email
      #       _provider, _uid, _email = _provider.split('-')
      #     end
      #     App.logger.debug "RW Rom users_relation#by_guid #{[_provider, _uid, _email]}"
      #     rslt = where :provider => _provider, :uid => _uid, :email => _email
      #     #App.logger.debug "RW Rom users_relation#by_guid result:"
      #     #App.logger.debug rslt.to_a
      #     rslt
      #   end
      
    end # identities_rel 

        
    #   begin
    #     puts "RackWarden droping table 'identities' in database: #{identities_rel.dataset}"
    #     config.default.connection.drop_table?(identities_rel.dataset.to_sym)
    #     puts "RackWarden creating table 'identities' in database: #{identities_rel.dataset}"
    #     config.default.connection.create_table?(identities_rel.dataset.to_s) do
    #       # rel.schema.attributes.each do |k,v|
    #       #   name = k.to_sym
    #       #   type = v.primitive.is_a?(Dry::Types::Definition) ? v.primitive.primitive : v.primitive
    #       #   puts "column #{name}, #{type}"
    #       #   column name, type
    #       # end
    #       primary_key :id, Integer
    #       column :user_id, Integer
    #       column :email, String
    #       column :provider, String
    #       column :uid, String
    #       column :info, String
    #       column :credentials, String
    #       column :extra, String
    #       column :created_at, DateTime   #, :default=>DateTime.now  # This doesn't work here as the datetime is frozen.
    #     end
    #     #puts "RackWarden created new table in database: #{identities_rel.dataset}"
    #   rescue
    #     puts "RackWarden trouble creating Identities table: #{$!}"
    #   end
    
  end # RomConfig
  


  #####  REPOS  #####
  
  ## Put domain-specific methods in this class.
  # TODO: Make this a base repo to inherit from.
  class UserRepoClass < ROM::Repository[:users]
    
    # You can also bring other relations into this repo (mostly for associations & aggregates).
    #relations :users, :sequence
        
    commands :create, :update => :by_pk, :delete => :by_pk  #by_pk is a rom-sql thing
        
    # Always return any call to users relation as a User 
    def users
      super.as(User)
    end
    
    def query(*args)
      users.query(*args)
    end
    
    def ids
      users.ids
    end
    
    def by_id(_id)
      users.by_id(_id).one
    end
    alias_method :get, :by_id
    
    def first
      users.first
    end
    
    def last
      users.last.one
    end
    
    # An 'all' method really should not be here,
    # since when the table gets large, it won't make any sense.
    def all
      users.to_a
    end
    
    def count
      users.count
    end
    
    ## Make it easier to save changed models.
    def save_attributes(_id, _attrs)
      #puts "UserRepoClass#save_attributes"
      #puts [_id, _attrs].to_yaml
      _changeset = changeset(_id, _attrs)
      case
      when _changeset.update?
        #puts "\nChangeset diff #{_changeset.diff}"
        saved = update(_id, _changeset)
      when _changeset.create?
        saved = create(_changeset)
      end
      #puts "\nResponse from updater"
      #puts saved.to_yaml
      saved
    end
    
    def locate_from_identity(identity)
      query(email: identity.email).union(query(id: identity.user_id)).first
    end
    
    def create_from_identity(identity)
      if identity.email.to_s != ''
        new_rec = create(:email => identity.email, :username => identity.email)
        (identity.user_id = new_rec.id) #&& identity.save
        RackWarden::User.new(new_rec)
      else
        raise "RackWarden::UsersRepo.create_from_identity: email cannot be empty."
      end
    end
    
    def locate_or_create_from_identity(identity)
      locate_from_identity(identity) || create_from_identity(identity)
    end
    
    
    ###  Class methods from legacy Identity model  ###
    
	  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
	  # This is not currently used in RackWarden (has it's own auth logic section). WHAT?!?! Yes it is used in current RW.
	  def authenticate(login, password)
	    # hides records with a nil activated_at
	    #if repository.adapter.to_s[/filemaker/i]
		    # FMP
		    #u = first(:username=>"=#{login}", :activated_at=>'>1/1/1980') || first(:email=>"=#{login}", :activated_at=>'>1/1/1980')
		    u = query('username = :login and activated_at > :time', :login=>login, :time=>Time.new('1970-01-01 00:00:00')).union \
		      query('email like :login and activated_at > :time', :login=>"#{login}%", :time=>Time.new('1970-01-01 00:00:00'))
		    App.logger.debug "USER.authenticate #{u.inspect}"
		    u = u.respond_to?(:first) ? u.first : u
		  #else
		    # SQL
		    #u = first(:conditions => ['(username = ? or email = ?) and activated_at IS NOT NULL', login, login])
			#end
	    if u && u.authenticate(password)
	    	# This bit clears a password_reset_code (this assumes it's not needed, cuz user just authenticated successfully).
	    	(u.password_reset_code = nil; u.save) if u.password_reset_code
	    	u
	    else
	    	nil
	    end
	  end

	  def find_for_forget(email) #, question, answer)
	    first(:conditions => ['email = ? AND (activation_code IS NOT NULL or activated_at IS NOT NULL)', email])
	  end
	  
	  def find_for_activate(code)
	  	decoded = App.uri_decode(code)
	  	App.logger.debug "RW find_for_activate with #{decoded}"
	    first :activation_code => "#{decoded}"
	  end    
    
  end # UserRepoClass
  
  
  
  
  
  class IdentityRepoClass < ROM::Repository[:identities]
    
    commands :create, :update=>:by_pk, :delete=>:by_pk
        
    def identities
      super.as(RackWarden::Identity)
    end
    
    def query(*args)
      identities.query(*args)
    end
    
    # I think rom-sql already does this as :by_pk,
    # but how does it work?
    # def by_primary_key(provider, uid, email)
    #   identities.where(uid: uid, provider: provider, email: email).one
    # end
    
    def ids
      identities.ids
    end
    
    def by_id(_id)
      identities.by_id(_id).one
    end

    def first
      identities.first
    end
        
    def last
      identities.last.one
    end
    
    #   def by_guid(*args)
    #     App.logger.debug "RW Rom IdentityRepo#by_guid, args: #{args}"
    #     identities.by_guid(*args).one    #identities.by_guid(*args).tap{|i| !i.nil? && i.one}
    #   end
    
    # Get a single record by uique combo of provider-uid. Email is no longer used.
    # Args can be passed separately or as a string delimited by a colon ':'.
    #def by_guid(_provider, _uid=nil)
    def by_guid(_provider, _uid=nil)
      unless _uid 
        _provider, _uid = _provider.split(':')
      end
      App.logger.debug "RW UsersRepo#by_guid #{[_provider, _uid]}"
      rslt = query :provider => _provider, :uid => _uid
      #App.logger.debug "RW Rom users_relation#by_guid result:"
      #App.logger.debug rslt.to_a
      rslt.one
    end
    
    
    ## Make it easier to save changed models.
    # TODO: Somewhere the yaml objects in the entities are getting
    # re-saved as plain hashes.
    # I think the changeset isn't aware of the to/from yaml stuff.
    # TODO: Try this manually and see what happens.
    def save_attributes(_id, _attrs)
      App.logger.debug "RW Rom IdentityRepo#save_attributes (id: #{_id})"
      _changeset = changeset(_id, _attrs)
      case
      when _changeset.update?
        App.logger.debug "RW Rom IdentityRepo#save_attributes update"
        saved = update(_id, _changeset)
      when _changeset.create?
        App.logger.debug "RW Rom IdentityRepo#save_attributes create"
        saved = create(_changeset)
      end
      #App.logger.debug "RW Rom identity changeset"
      #App.logger.debug _changeset.to_yaml
      saved
    end

    # TEST:
    # ih = YAML.load_file '../RackWarden/spec/info_hash_data.yml'
    # ah = OmniAuth::AuthHash.new(provider:'slack', uid:12345, email:'wbr@mac.com', info:ih)
    # #i = RackWarden::IdentityRepo.create(provider:'slack', uid:12345, email:'wbr@mac.com', info:ih)
    # i = RackWarden::IdentityRepo.create(ah)
    # #i = RackWarden::IdentityRepo.create(ah.to_h)
    # ah_from_db = RackWarden::IdentityRepo.first
    # ah_from_db.user_id=1
    # ah2_from_db = RackWarden::IdentityRepo.first
    
    def create_from_auth_hash(auth_hash)
      App.logger.debug "RW ROM IdentityRepo.create_from_auth_hash"  # #{auth_hash.to_yaml}"
      auth_hash.email = auth_hash.info.email
      # This might erase all references to the AuthHash class.
      #Identity.new(create(auth_hash.merge({:email => auth_hash.info.email})))
      Identity.new(create(auth_hash))
      # rescue
      #   App.logger.info "RW create_from_auth_hash raised an exception: #{$!}"
      #   nil
    end
    
    
    ## Should not be needed any more.
    # def load_legacy_yaml
    #   # This isn't working.
    #   identities = YAML.load_file 'identities.yml'
    #   identities.each do |identity|
    #     auth_hash = identity.instance_variable_get(:@auth_hash)
    #     create(auth_hash.merge({user_id: identity.user_id, email: auth_hash.info.email}))
    #   end
    #   puts "RackWarden::Identity loaded records into sqlite3::memory"
    #   
    #   ## So try this, it works.
    #   # ii = YAML.load_file 'identities.yml'
    #   # h = ii.last.instance_variable_get(:@auth_hash)
    #   # r = RackWarden::IdentityRepo.create h
    #   
    #   # You can also use this for cleanup
    #   #RackWarden::RomContainer.gateways[:default].connection.execute("select * from rack_warden_identities")
    # end
    
    def upsert_from_auth_hash(auth_hash)
      App.logger.debug "RW Rom upsert_from_auth_hash:"
      auth_hash.email = auth_hash.info.email
      identity = locate_from_auth_hash(auth_hash)
      if identity
        # Using save_attributes here doesn't seem to work.
        #Identity.new(save_attributes(identity.id, auth_hash))
        auth_hash.email = auth_hash.info.email
        Identity.new(update(identity.id, auth_hash))
      else
        create_from_auth_hash(auth_hash)
      end
      # rescue
      #   App.logger.debug "RW Rom upsert_from_auth_hash raised exception: #{$!}"
      #   nil
    end
    
    
    
    ###  Class methods from legacy Identity model  ###
    
    def locate_or_create_from_auth_hash(auth_hash) # identifier should be auth_hash
      App.logger.debug "RW Rom IdentityRepo locate_or_create"
      identity = (locate_from_auth_hash(auth_hash) || create_from_auth_hash(auth_hash))
    end
    
    def locate_from_auth_hash(auth_hash) # locate existing identity given raw auth_hash.
      App.logger.debug "RW Rom IdentityRepo locate_from_auth_hash"
      by_guid(auth_hash.provider, auth_hash.uid)  #, auth_hash.info.email)
    end    
    
  
    
  end # IdentityRepoClass
  


  ## Finalize ROM
  
  # Register the externally defined relation
  #RomConfig.register_relation AnotherUsersRelation
  
  # Finalize the rom config
  RomContainer = ROM.container(RomConfig)
  
  # Create rom repos with containers
  UserRepo = UserRepoClass.new(RomContainer)
  IdentityRepo = IdentityRepoClass.new(RomContainer)
  


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

  

  # Require all ruby files in a directory, recursively.
  # See http://stackoverflow.com/questions/10132949/finding-the-gem-root
  Dir.glob(File.join(RackWarden.root, 'lib/rack_warden/models/', '**', '*.rb'), &method(:require))


end # SlackSpace