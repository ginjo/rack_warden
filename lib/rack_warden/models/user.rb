
module RackWarden

  class User
    include DataMapper::Resource
    include BCrypt

    property :id, Serial, key: true
    property :username, String, length: 128, unique: true, required: true, default: lambda {|r,v| r.instance_variable_get :@email}
    property :email, String, length: 128, unique: true, required: true #, default: 'error'

    property :password, BCryptHash
    
    # before :valid?, :set_username
    # before :save, :set_username
    
    # def set_username
    #   puts "SETTING USERNAME"
    #   @username = @email unless @username
    # end

    def authenticate(attempted_password)
      if self.password == attempted_password
        true
      else
        false
      end
    end
  end
  
  # # Create a test User
  # if User.count == 0
  #   @user = User.create(username: "admin")
  #   @user.password = "admin"
  #   @user.save
  # end
end # module