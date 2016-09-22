module RackWarden

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
  

end # RackWarden