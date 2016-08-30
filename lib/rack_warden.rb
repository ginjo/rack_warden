module RackWarden
  # Incase you are using this library without the gem loaded.
  PATH = File.expand_path(File.dirname(__FILE__))
  #puts "RW PATH #{PATH}"
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)
  if ENV['RACK_WARDEN_STANDALONE']; STANDALONE=true; end
  
  # NEW: Get gem root path.
  # This will only work in ruby 2+
  def self.root
    File.dirname __dir__
  end
end


###  OMNIAUTH CODE  ###
require 'forwardable'
require 'omniauth'
#require 'omniauth-github'
#require 'omniauth-google-oauth2'
#require 'omniauth-slack'
###  END OMNIAUTH CODE  ###

require "sinatra/base"
require "sinatra/contrib" # not compatible with rails 2.3 because of rack dependency conflict.
require "rack/flash" # this somehow loads rack/flash3
require "rack/contrib/cookies"  # This is needed to set cookies in warden callbacks.
require 'bcrypt'
require 'data_mapper'
require 'warden'
require 'yaml'
require 'erb'
require 'tilt/erb'  # An error somwhere suggested this be explicity required.
require 'rack_warden/core_patches'
require 'rack_warden/rom'

autoload :Mail, 'mail'
autoload :URI, 'open-uri'
autoload :Base64, 'base64'

module RackWarden
  autoload :App, 'rack_warden/app'
  autoload :Env, 'rack_warden/env'
  #autoload :User, "rack_warden/models"
  #autoload :Pref, "rack_warden/models"
  #autoload :Identity, "rack_warden/models/identity"  # OMNIAUTH
  autoload :Mail, "rack_warden/mail"
  autoload :Routes, "rack_warden/routes"
  autoload :VERSION, "rack_warden/version"
  autoload :WardenConfig, "rack_warden/warden"
  autoload :RackWardenClassMethods, "rack_warden/rw_class_methods"
  autoload :UniversalHelpers, "rack_warden/universal_helpers"
  autoload :RackWardenHelpers, "rack_warden/rw_helpers"
  # Autload patched versions of respond_with & namespace.
  # respond_with handles uri dot-format extension,
  # and namespace handles require_login.
  #autoload :RespondWith, "rack_warden/sinatra/respond_with"
  #autoload :Namespace, "rack_warden/sinatra/namespace"
  autoload :Frameworks, "rack_warden/frameworks"
  module Frameworks
    autoload :Sinatra, 'rack_warden/frameworks/sinatra'
    autoload :Rails, 'rack_warden/frameworks/rails'
    autoload :Rack, 'rack_warden/frameworks/rack'
  end
  
  # OLD:
  # def self.new(*args)
  # 	App.new(*args)
  # end
  
  # Creating a new App class before a new App instance
  # allows multiple rw instances to be used in a single ruby process,
  # for example, a rack app with multiple rack or sinatra endpoints.
  # To pass settings to each instance of rw, pass them with the 'use' method:
  # Usage: class MyApp; use RackWarden, :require_login=>false; ... end; class OtherApp; use RackWarden, :require_login => /protected.*/; end
	def self.new(*args)
    block = Proc.new if block_given?
    App.logger.debug "RW RackWarden.new with args: #{args}, block_given? #{block_given?}"
    Class.new(App).new(*args, &block)
	end
	

	# Utility to get middleware stack. Maybe temporary.
	def self.middleware_classes(app=nil)                                                                                                                                              
	  r = [app || Rack::Builder.parse_file(File.join(Dir.pwd, 'config.ru')).first]
	  while ((next_app = r.last.instance_variable_get(:@app)) != nil)
	    r << next_app
	  end
	  r.map{|e| e.instance_variable_defined?(:@app) ? e.class : e }
	end
	#app = Rack::Builder.parse_file('config.ru').first
	#puts middleware_classes(app).inspect
	
	# Shortcut/sugar to app
	def self.settings
		App.settings
	end
	
	# Not sure what situation this is used for.
	def self.included(base)
		App.logger.info "RW self.included into BASE #{base}, ID #{base.object_id}"
		# Force initialize rack_warden, even if not all the settings are known yet.
		#App.new base
	end
	
	# This is for Sinatra apps only.
	# You have to register rw to get the class methods & dsl into the user's app.
	# BUT, we need to let the user pass middleware arguments as well,
	# so they have to ALSO use the 'use' method.
	def self.registered(app)
  	App.logger.info "RW self.registered with app #{app}, ID #{app.object_id}"
		App.setup_framework app
		# TODO: Do we need to check installed middleware to make sure we only have one instance of RW,
		# in case someone registers RW with multiple sinatra apps in the same ruby process (which seems to be a common practice)?
		# No, multiple rw instances should be ok. See commit 15e0ccab97fd1ca7f6835eb27d3c9fa1f7784571.
		#app.use self  # Disabled this, because endpoint app needs to be able to pass middleware arguments.
	end
	
	#Loads the App class, as soon as this module loads.
	App
	
	# Enable this for automatic sinatra top-level registration.
	#Sinatra.register self
  
end
