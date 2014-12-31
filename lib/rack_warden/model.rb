#require 'bcrypt'
DataMapper::Logger.new(File.join(Dir.pwd, 'log', 'rack_warden.log'))
DataMapper.setup(:default, RackWarden::App.database_config)

# Do DataMapper.repository.adapter to get connection info for this connection.

class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, key: true
  property :username, String, length: 128, required: true, unique: true, default: lambda {|r,v| r.instance_variable_get :@email}
  property :email, String, length: 128, required: true, unique: true, default: 'error'

  property :password, BCryptHash

  def authenticate(attempted_password)
    if self.password == attempted_password
      true
    else
      false
    end
  end
end

# Tell DataMapper the models are done being defined
DataMapper.finalize

# Update the database to match the properties of User.
DataMapper.auto_upgrade!

# # Create a test User
# if User.count == 0
#   @user = User.create(username: "admin")
#   @user.password = "admin"
#   @user.save
# end