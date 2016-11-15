module RackWarden

  module Rom

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
        rslt = ensure_bcrypt(dat).to_s
        rslt == '' ? nil : rslt
      end
      
      ToYaml = Dry::Types::Definition.new(String).constructor do |dat|
        if dat.is_a?(::String)
          #App.logger.debug "RW ToYaml keeping string: #{dat[0..100]}"
          dat
        else
          #App.logger.debug "RW ToYaml converting to yaml: #{dat.to_yaml[0..100]}"
          dat.to_yaml
        end
      end
      
      FromYaml = Dry::Types::Definition.new(Hash).constructor do |dat|
        #puts "FromYaml constructor with data: #{dat}"
        if dat.is_a?(::String)
          YAML.load(dat.to_s) || nil
        else
          dat
        end
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
        if dat.is_a?(::String)
          Marshal.load(dat.to_s)
        else
          dat
        end
      end
      
    end # Types

  end # Rom
end # RackWarden