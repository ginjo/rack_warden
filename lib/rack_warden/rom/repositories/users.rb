require_relative 'base'

module RackWarden
  module Rom
    module Repositories
      class UsersClass < Base[:users]
        
        #relations :users
        #root :users
            
        commands :create, :update => :by_pk, :delete => :by_pk  #by_pk is a rom-sql thing
        
        def locate_from_identity(identity)
          query(email: identity.email).union(query(id: identity.user_id)).first
        end
        
        def create_from_identity(identity)
          if identity.email.to_s != ''
            new_rec = create(:email => identity.email, :username => identity.email)
            (identity.user_id = new_rec.id) && identity.save
            new_rec
          else
            raise "RackWarden::UsersRepo.create_from_identity: email cannot be empty."
          end
        end
        
        def locate_or_create_from_identity(identity)
          locate_from_identity(identity) || create_from_identity(identity)
        end
        
        
        ###  Class methods from legacy Identity model  ###
        
    	  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    	  # This is not currently used in RackWarden (has it's own auth logic section). WHAT?!?! Yes it is used in current RW. Why did I write this?
    	  # TODO: The query logic/language of this method needs to be database-agnostic,
    	  #       so it needs to be handled at the relation level.
    	  def authenticate(login, password)
  		    u = users.query_for_authenticate(login).as(entity).one
  		    App.logger.debug "RW users-repo.authenticate, user: #{u}"
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
    	  
      end # UsersClass
    end # Repositories
  end # Rom
end # RackWarden