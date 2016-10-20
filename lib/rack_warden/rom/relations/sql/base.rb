module RackWarden
  module Rom
    module Relations
      module Sql
    
        class Base < ROM::Relation[:sql]
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
          
          def table_exists?
            dataset.db.table_exists?(table)
          end
          
          def drop_table
            App.logger.warn "RackWarden droping table '#{table}' in database: #{dataset}"
            dataset.db.drop_table?(table)
          end
          
        end # Base
        
      end # Sql
    end # Relation
  end # Rom
end # RackWarden