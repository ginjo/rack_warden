require_relative 'base'

module RackWarden
  module Rom
    module Repositories
      class Identities < Base#[:identities]
        
        relations :identities
        
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
        alias_method :get, :by_id
    
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
        
        
        #   ## Makes it easier to save changed models.
        #   # TODO: Somewhere the yaml objects in the entities are getting
        #   # re-saved as plain hashes.
        #   # I think the changeset isn't aware of the to/from yaml stuff.
        #   # TODO: Try this manually and see what happens.
        #   def save_attributes(_id, _attrs)
        #     App.logger.debug "RW Rom IdentityRepo#save_attributes (id: #{_id})"
        #     App.logger.debug _attrs.to_yaml
        #     _attrs.delete_if {|k,v| v==nil} unless _id
        #     _changeset = changeset(_id, _attrs)
        #     #App.logger.debug "RW Rom identity changeset"
        #     #App.logger.debug _changeset.to_yaml
        #     case
        #     when _changeset.update?
        #       App.logger.debug "RW Rom IdentityRepo#save_attributes update"
        #       App.logger.debug "RW Rom identity changeset.diff"
        #       App.logger.debug _changeset.diff.to_yaml
        #       saved = update(_id, _changeset)
        #     when _changeset.create?
        #       App.logger.debug "RW Rom IdentityRepo#save_attributes create"
        #       saved = create(_changeset)
        #     end
        #     saved
        #   end
    
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
        
      end # Identities
    end # Repositories
  end # Rom
end # RackWarden