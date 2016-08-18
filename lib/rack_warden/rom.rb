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
      #puts "\nToYaml constructor with data: #{dat}"
      dat.to_yaml
    end
    
    FromYaml = Dry::Types::Definition.new(Hash).constructor do |dat|
      #puts "FromYaml constructor with data: #{dat}"
      YAML.load(dat.to_s)
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
        attribute :user_id, Types::String
        attribute :email, Types::String
        attribute :provider, Types::String
        attribute :uid, Types::String
        attribute :info, Types::ToYaml
        attribute :credentials, Types::ToYaml
        attribute :extra, Types::ToYaml
        attribute :created_at, Types::DateTime
        primary_key :id
        primary_key :provider, :uid, :email
      end
      
      include RelationIncludes
      
      # Get a single record by uique combo of provider-uid-email.
      # Args can be passed as all 3 or string concat of all 3 (separated by dash "-").
      # TODO: Use something other than dash, it will eventually conflict with data.
      def by_guid(provider, uid=nil, email=nil)
        unless uid && email
          by_guid *provider.split('-')
        else
          where :provider => provider, :uid => uid, :email => email
        end
      end
      
    end # identities_rel
        
        
    begin
      #config.default.connection.drop_table?(identities_rel.dataset.to_sym) && config.default.connection.drop_table(identities_rel.dataset.to_sym)
      #puts "RackWarden creating new table in database: #{identities_rel.dataset}"
      #config.default.connection.create_table?(identities_rel.dataset.to_s) && config.default.connection.create_table(identities_rel.dataset.to_s) do
      config.default.connection.create_table?(identities_rel.dataset.to_s) do
        # rel.schema.attributes.each do |k,v|
        #   name = k.to_sym
        #   type = v.primitive.is_a?(Dry::Types::Definition) ? v.primitive.primitive : v.primitive
        #   puts "column #{name}, #{type}"
        #   column name, type
        # end
        primary_key :id, Integer
        column :user_id, String
        column :email, String
        column :provider, String
        column :uid, String
        column :info, String
        column :credentials, String
        column :extra, String
        column :created_at, DateTime, :default=>Time.now
      end
      #puts "RackWarden created new table in database: #{identities_rel.dataset}"
    rescue
      puts "RackWarden trouble creating Identities table: #{$!}"
    end
    
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
    
    def query(conditions)
      users.query(conditions)
    end
    
    def ids
      users.ids
    end
    
    def by_id(_id)
      users.by_id(_id).one
    end
    
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
  
  end # UserRepoClass
  
  
  class IdentityRepoClass < ROM::Repository[:identities]
    
    commands :create, :update=>:by_pk, :delete=>:by_pk
        
    def identities
      super.as(Identity)
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
    
    def by_guid(*args)
      identities.by_guid(*args).one
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
    

    def self.load_legacy_yaml
      # This isn't working.
      identities = YAML.load_file 'identities.yml'
      identities.each do |identity|
        auth_hash = identity.instance_variable_get(:@auth_hash)
        IdentityRepo.create(auth_hash.merge({user_id: identity.user_id, email: auth_hash.info.email}))
      end
      puts "RackWarden::Identity loaded records into sqlite3::memory"
      
      ## So try this, it works.
      # ii = YAML.load_file 'identities.yml'
      # h = ii.last.instance_variable_get(:@auth_hash)
      # r = RackWarden::IdentityRepo.create h
      
      # You can also use this for cleanup
      #RackWarden::RomContainer.gateways[:default].connection.execute("select * from rack_warden_identities")
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
    
    # # Clean this up, maybe put in base model class.
    # def self.initialize_attributes(attrbts=RomContainer.relation(:users).schema.attributes.tap{|a| a.delete(:encrypted_password)})
    #   #puts "\nInitializing attributes for User model"
    #   attrbts.merge!({:encrypted_password => Types::BCryptPassword})
    #   attrbts.each do |k,v|
    #     #puts "Attribute: #{k}, #{v.primitive}"
    #     attribute k, v
    #     attr_writer k
    #   end
    # end
    
    # initialize_attributes
            
    def self.repo
      @repo ||= eval("#{name}RepoClass").new(RomContainer)
    end

    # Needed to handle extra non-db attributes,
    # since the dry-struct deletes them within its own 'new'.
    # All of dry-structs magic appears to happen at the class.new method (in C code probably).
    def self.new(hash={})
      new_instance = super(hash)
      extra_attrs = hash.dup.delete_if {|k,v| new_instance.instance_variables.include?(:"@#{k}")}
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
    
    def save
      #set_password
      yield if block_given?
      resp = repo.save_attributes self[:id], to_h
      self.update(resp.to_h)
      true
    rescue
      puts "#{self.class.name}#save ERROR: #{$!}"
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