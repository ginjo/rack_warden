
module RackWarden

  class User
    include DataMapper::Resource
    include BCrypt
    
    def self.default_repository_name; App.repository_name; end
    
    # DataMapper will build a user table name from the containing modules: rack_warden_users.
    storage_names[App.repository_name] = App.user_table_name if App.user_table_name

    property :id, Serial, :key => true
    property :username, String, :length => 128, :unique => true, :required => true, :default => lambda {|r,v| r.instance_variable_get :@email}
    property :email, String, :length => 128, :unique => true, :required => true, :format=>:email_address
    property :encrypted_password, BCryptHash, :writer => :protected, :default => lambda {|r,v| r.instance_variable_get :@password}
    
    attr_accessor :password, :password_confirmation
    
    
    ###  VALIDATION  ###
    
    validates_presence_of 		:password, :password_confirmation, :if => :password_required?
		validates_confirmation_of :password, :if => :password_required?
		validates_length_of				:password, :min => 8, :if => :password
		validates_with_method			:password, :method => :valid_password_elements, :if => :password
		validates_length_of				:password_confirmation, :within => 8..40, :when => [:require_password, :user]
				
				
		# check validity of password if we have a new resource, or there is a plaintext password provided
    def password_required?
      password || new?
    end
				
	  # Validation returns nil if valid
		def valid_password_elements
			unless password_element_count >= 2
				message = "Passwords must be minimum 8 characters in length
				and contain at least two of the following character types: uppercase,
				lowercase, numbers, symbols."
				[false, message]
			else
				true
			end
		end
	
		# Returns number of specified character classes found in pwd
		def password_element_count(pwd=password, character_classes = %w[upper lower digit punct])
			character_classes.find_all{|c| pwd.to_s[/[[:#{c}:]]/]}.size
		rescue
			0
		end
		
		
		###  INSTANCE  ###

    def authenticate(attempted_password)
      if self.encrypted_password == attempted_password
        true
      else
        false
      end
    end
    
	  def authorized?(options={})
	  	#options[:request].script_name[/login|new|create|logout/] ||
	  	self.id==1
	  end
	      
    
  end
  
  
  # # Create a test User
  # if User.count == 0
  #   @user = User.create(:username => "admin")
  #   @user.password = "admin"
  #   @user.save
  # end
end # module