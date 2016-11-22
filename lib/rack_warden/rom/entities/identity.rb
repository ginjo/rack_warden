require_relative 'base'
require_relative '../types'

module RackWarden
  module Rom
    module Entities
  
      # TODO: Make sure OmniAuth classes are loaded before loading auth_hash yaml.
  
      class Identity < Base[Proc.new{Repositories::IdentitiesRepo}]
      
        # I don't think this is used anymore (was in old rw identity model).
        #attr_accessor :auth_hash  #, :user_id
        
        # Use schema attributes from base relation, put overrides in the block.
        initialize_attributes do
          {
          :info => Types::FromYaml,
          :credentials => Types::FromYaml,
          :extra => Types::FromYaml,
          :created_at => Types::DateTime,
          :updated_at => Types::DateTime     
          }
        end
        
        def is_admin?
          info.is_admin
        end
        
        def guid
          "#{provider}:#{uid}"
        end
        
        # Get user and link it with identity.
        def user
          _user = User.locate_or_create_from_identity(self)
          if _user   #(_user.is_a?(RackWarden::User) && user_id.to_s.empty?)
            if user_id.to_s.empty?
              self.user_id = _user.id
              save
            end
            # This used to store entire identity in user,
            # but I don't know why. So now just storing id.
            # See User model current_identity method.
            _user.current_identity = id   #self
          else
            App.logger.debug "RW Identity#user could not be located or created from identity"
          end
          _user
        end

        def name; info['name']; end
        #def email; info['email']; end
        
        def username; name; end
      
        
      end # Identity
    end # Entities
  end # Rom
end # RackWarden