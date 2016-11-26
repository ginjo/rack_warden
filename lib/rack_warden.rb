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
require 'warden'
require 'yaml'
require 'erb'
require 'tilt/erb'  # An error somwhere suggested this be explicity required.
require 'dry-types'
require 'dry-struct'
require 'rack_warden/core_patches'
require 'rack_warden/rom'


autoload :Mail, 'mail'
autoload :URI, 'open-uri'
autoload :Base64, 'base64'

module RackWarden
  autoload :App, 'rack_warden/app'
  autoload :RackEnv, 'rack_warden/rack_env'
  autoload :Mail, "rack_warden/mail"
  autoload :Routes, "rack_warden/routes"
  autoload :VERSION, "rack_warden/version"
  autoload :WardenConfig, "rack_warden/warden"
  autoload :RackWardenClassMethods, "rack_warden/rw_class_methods"
  autoload :UniversalHelpers, "rack_warden/universal_helpers"
  autoload :RackWardenHelpers, "rack_warden/rw_helpers"
  autoload :FrameworkHelpers, "rack_warden/framework_helpers"
  module Frameworks
    autoload :Sinatra, 'rack_warden/frameworks/sinatra'
    autoload :Rails, 'rack_warden/frameworks/rails'
    autoload :Rack, 'rack_warden/frameworks/rack'
  end

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
	
	
	#Loads the App class, as soon as this module loads.
	App
	
	# Enable this for automatic sinatra top-level registration.
	#Sinatra.register self
  
end
