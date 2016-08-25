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
  autoload :AppClassMethods, "rack_warden/helpers"
  autoload :UniversalHelpers, "rack_warden/helpers"
  autoload :RackWardenHelpers, "rack_warden/helpers"
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
		Class.new(App).new(*args)
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
	
	def self.included(base)
		App.logger.warn "RW self.included into BASE #{base}, ID #{base.object_id}"
		# Force initialize rack_warden, even if not all the settings are known yet.
		#App.new base
	end
	
	def self.registered(app)
		App.setup_framework app
		# TODO: Do we need to check installed middleware to make sure we only have one instance of RW,
		# in case someone registers RW with multiple sinatra apps in the same ruby process (which seems to be a common practice)?
		app.use self
	end
	
	#Loads the App module, as soon as this module loads.
	App
	
	# Enable this for automatic sinatra top-level registration.
	#Sinatra.register self
  
end
