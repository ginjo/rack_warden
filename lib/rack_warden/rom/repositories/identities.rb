require_relative 'base'

module RackWarden
  module Rom
    module Repositories
      class IdentitiesClass < Base[:identities]
        
        #relations :identities
        #root :identities
        
        commands :create, :update=>:by_pk, :delete=>:by_pk
        
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
        
        def create_from_auth_hash(auth_hash)
          App.logger.debug "RW ROM IdentityRepo.create_from_auth_hash"  # #{auth_hash.to_yaml}"
          prep_auth_hash_for_identity auth_hash
          create(auth_hash)
          # rescue
          #   App.logger.info "RW create_from_auth_hash raised an exception: #{$!}"
          #   nil
        end
        
        def upsert_from_auth_hash(auth_hash)
          App.logger.debug "RW Rom Identities Repo upsert_from_auth_hash"
          identity = locate_from_auth_hash(auth_hash)
          if identity
            prep_auth_hash_for_identity auth_hash
            update(identity.id, auth_hash)
          else
            create_from_auth_hash(auth_hash)
          end
          # rescue
          #   App.logger.debug "RW Rom upsert_from_auth_hash raised exception: #{$!}"
          #   nil
        end
        
        def prep_auth_hash_for_identity(auth_hash)
          if auth_hash.info.email
            auth_hash.email = auth_hash.info.email
          end
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