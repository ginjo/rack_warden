module RackWarden
  # Incase you are using this library without the gem loaded.
  PATH = File.expand_path(File.dirname(__FILE__))
  #puts "RW PATH #{PATH}"
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)
end

require "sinatra/base"
#require "sinatra/contrib" # not compatible with rails 2.3 because of rack dependency conflict.

# from 3rd party gems
require "sinatra/namespace"
#require "sinatra/respond_to"
require "rack/flash" # this somehow loads rack/flash3

# Local files taken from sinatra-contrib project.
require "rack_warden/sinatra/respond_with"

require "rack/contrib/cookies"  # This is needed to set cookies in warden callbacks.
require 'bcrypt'
require 'data_mapper'
require 'warden'
require 'yaml'
require 'tilt/erb'  # An error somwhere suggested this be explicity required.
require 'rack_warden/core_patches'

autoload :Mail, 'mail'
autoload :URI, 'open-uri'
autoload :Base64, 'base64'

module RackWarden
  autoload :App, 'rack_warden/app'
  autoload :User, "rack_warden/models"
  autoload :Pref, "rack_warden/models"
  autoload :Mail, "rack_warden/mail"
  autoload :Routes, "rack_warden/routes"
  autoload :VERSION, "rack_warden/version"
  autoload :WardenConfig, "rack_warden/warden"
  autoload :UniversalHelpers, "rack_warden/helpers"
  autoload :RackWardenHelpers, "rack_warden/helpers"
  module Frameworks
    autoload :Base, 'rack_warden/frameworks'
    autoload :Sinatra, 'rack_warden/frameworks/sinatra'
    autoload :Rails, 'rack_warden/frameworks/rails'
  end
  
  # Make this module a pseudo-class appropriate for middlware stack. Use RackWarden for older rails apps (rather than 'RackWarden::App')
	def self.new(*args)
		App.new(*args)
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
  
end
