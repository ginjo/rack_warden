require_relative 'base'
require_relative '../types'

module RackWarden
  module Rom
    module Entities
  
      class User < Base[:users]
        attr_accessor :password, :password_confirmation, :current_identity
        
        # Use schema attributes from base relation, put overrides in the block.
        initialize_attributes do
          {:encrypted_password => Types::BCryptPassword,
          :created_at => Types::DateTime,
          :updated_at => Types::DateTime
          }
        end
        
        def update(data)
          super(data) do
            set_password
          end
        end
        
        def save
          super do
            set_password
          end
        end

        #####  DOMAIN SPECIFIC METHODS  #####
    
        # The dry-struct only applies Types at construction.
        def encrypted_password=(pswd)
          @encrypted_password = Types::BCryptPassword[pswd]
        end
        
        #private :'encrypted_password='
        
        def set_password
          #puts "\nSetting User password with User:"
          #puts self.to_yaml
          if (@password == @password_confirmation && !@password.to_s.empty?)
            self.encrypted_password = @password
            @password, @password_confirmation = nil, nil
          end
          true
        end
        
        #   def authenticate(pswd)
        #     encrypted_password == pswd
        #   end        
        
        
        
        #####  From legacy RackWarden::User model  #####
        
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

    		
    		###  INSTANCE  ###
    
        def authenticate(attempted_password)
          if self.encrypted_password == attempted_password
            true
          else
            false
          end
        end
        
        # TODO: Fill this out with whatever you want.
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
    	
        # TODO: Update this with modern tech (SecureRandom ?)
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
        
        def current_identity
          Identity.by_id @current_identity if @current_identity
        end
        
      end # User
    end # Entities
  end # Rom
end # RackWarden