
module RackWarden

  class User < Model::Base
		raise_on_save_failure = true
    # DataMapper will build a user table name from the containing modules: rack_warden_users.
    self.storage_names[App.repository_name] = App.user_table_name if App.user_table_name
    #self.field_map = App.user_field_map

		# If your key id field is a string with no auto-enter options, use this.
    #property :id, String, :key=>true, :unique=>true, :default => lambda {|r,v| Time.now._to_unique_id}
    #validates_presence_of			:id, :unless => :new?
    
    property :id, Serial
    property :username, String, :length => 128, :unique => true, :required => true, :default => lambda {|r,v| r.instance_variable_get :@email}
    property :email, String, :length => 128, :unique => true, :required => true, :format=>:email_address
    property :encrypted_password, BCryptHash, :writer => :protected, :default => lambda {|r,v| BCrypt::Password.create(r.instance_variable_get :@password)}
    property :remember_token, BCryptHash
    property :remember_token_expires_at, DateTime
    property :activated_at, DateTime
    property :activation_code, BCryptHash
    property :password_reset_code, BCryptHash
    
    
    attr_accessor :password, :password_confirmation
		
		before :create, :make_activation_code
		after :create, :send_activation
    
    ###  VALIDATION  ###
    
    validates_presence_of			:id, :unless => :new?
    validates_presence_of 		:password, :password_confirmation, :if => :password_required?
		validates_confirmation_of :password, :if => :password_required?
		validates_length_of				:password, :min => 8, :if => :password
		validates_with_method			:password, :method => :valid_password_elements, :if => :password
		validates_length_of				:password_confirmation, :within => 8..40, :when => [:require_password, :user]
		
						
		# check validity of password if we have a new resource, or there is a plaintext password provided
    def password_required?
      password || (new? && !encrypted_password)
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


		###  CLASS  ###

	  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
	  # This is not currently used in RackWarden (has it's own auth logic section).
	  def self.authenticate(login, password)
	    # hides records with a nil activated_at
	    #if repository.adapter.to_s[/filemaker/i]
		    # FMP
		    #u = first(:username=>"=#{login}", :activated_at=>'>1/1/1980') || first(:email=>"=#{login}", :activated_at=>'>1/1/1980')
		    u = all(:username=>login, :activated_at.gt=>Time.new('1970-01-01 00:00:00')) | all(:email.like=>login, :activated_at.gt=>Time.new('1970-01-01 00:00:00'))
		    puts "USER.authenticate"
		    puts u
		    u = u.respond_to?(:first) ? u.first : u
		  #else
		    # SQL
		    #u = first(:conditions => ['(username = ? or email = ?) and activated_at IS NOT NULL', login, login])
			#end
	    if u && u.authenticate(password)
	    	# This bit clears a password_reset_code (this assumes it's not needed, cuz user just authenticated successfully).
	    	(u.update_attributes(:password_reset_code => nil)) if u.password_reset_code
	    	u
	    else
	    	nil
	    end
	  end

	  def self.find_for_forget(email) #, question, answer)
	    first(:conditions => ['email = ? AND (activation_code IS NOT NULL or activated_at IS NOT NULL)', email])
	    #find :first, :conditions=>{:email=>email, :security_question=>question, :security_answer=>answer}
	  end
	  
	  def self.find_for_activate(code)
	  	decoded = App.uri_decode(code)
	  	App.logger.debug "RW find_for_activate with #{decoded}"
	    User.first :activation_code => "#{decoded}"
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
	  	self.id==1 || self.username == 'wbr'
	  end
	  
	  def remember_token?
	    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
	  end
	
	  # These create and unset the fields required for remembering users between browser closes
	  def remember_me
	    self.remember_token_expires_at = Time.now+(60*60*24*14)      #2.weeks.from_now.utc
	    self.remember_token            = "#{email}--#{remember_token_expires_at}"
	    save! && remember_token 
	  end
	
	  def forget_me
	    self.remember_token_expires_at = nil
	    self.remember_token            = nil
	    save!   #(false)
	  end

	  def activate
	    @activated = true
	    self.activated_at = Time.now
	    self.activation_code = nil
	    # added by wbr for auto-password generation from blank activation
	    self.encrypted_password.to_s.empty? ? self.new_random_password : nil
	    self.save!
	  end
	
	  # Returns true if the user has just been activated.
	  def recently_activated?
	    @activated
	  end
	
	  def make_activation_code
	    self.activation_code = (Time.now.to_s.split(//).sort_by {rand}.join)
	    App.logger.debug "RW make_activation_code result #{activation_code}"
	    activation_code
	  end
	  
	  def send_activation
			RackWarden::Mail.new({
			  :to				=>	email,
			  :subject	=>	"Signup confirmation",
			  :body			=>	App.render_template('rw_activation.email.erb', :user=>self)
			}).deliver!
	  end
	  

	  
	  ### Reset Password ###
	  
	  def forgot_password
			@forgotten_password = true
			self.make_password_reset_code
	  end
	
	  def reset_password
			# First update the password_reset_code before setting the 
			# reset_password flag to avoid duplicate email notifications.
			update_attributes(:password_reset_code => nil)
			@reset_password = true
			# These steps will activate an account that hasn't been activated yet, allowing the user to activate when lost/forgotten activation email.
			if activated_at == nil and activation_code != nil
				activate
			end
	  end
	
	  def recently_reset_password?
	   @reset_password
	  end
	
	  def recently_forgot_password?
			@forgotten_password
	  end
	  
	  # wbr - to resend activation email from existing record
	  def recent_manual_activation?
	    @manual_activation
	  end
	
	  def make_password_reset_code
			self.password_reset_code = ( Time.now.to_s.split(//).sort_by {rand}.join )
	  end
	  
	  ###  ###
	  
	  def new_random_password # should maybe be private?
	    self.make_password_reset_code # added by wbr for blank activation
	    @recently_generated_password = self.password_reset_code #added by wbr for blank activation
	    self.password = Digest::SHA1.hexdigest("--#{rand.to_s}--#{username}--")[0,10]
	    self.password_confirmation = self.password
	  end
	  
	  # returns password_reset_code if recently generated password
	  def recently_generated_password
	    @recently_generated_password
	  end	      
    
  end # User
  
  
  # # Create a test User
  # if User.count == 0
  #   @user = User.create(:username => "admin")
  #   @user.password = "admin"
  #   @user.save
  # end
end # module