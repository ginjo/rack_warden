module RackWarden
  # Incase you are using this library without the gem loaded.
  PATH = File.expand_path(File.dirname(__FILE__))
  puts "RW PATH #{PATH}"
  $LOAD_PATH.unshift(PATH) unless $LOAD_PATH.include?(PATH)
end

require "sinatra/base"
require "sinatra/flash"
require 'bcrypt'
require 'data_mapper'
require 'warden'
require 'open-uri'
require 'yaml'

# gem 'data_mapper'
# gem 'dm-sqlite-adapter'
# gem 'warden'

# require "rack_warden/app"
# require "rack_warden/version"

module RackWarden
  autoload :App, 'rack_warden/app'
  autoload :User, "rack_warden/models"
  autoload :Pref, "rack_warden/models"
  autoload :VERSION, "rack_warden/version"
  module Frameworks
    autoload :Base, 'rack_warden/frameworks'
    autoload :Sinatra, 'rack_warden/frameworks/sinatra'
    autoload :Rails, 'rack_warden/frameworks/rails'
  end
  
  # Make this module a pseudo-class appropriate for middlware stack.
	def self.new(*args)
		App.new(*args)
	end
	

	# Utility to get middleware stack
	def self.middleware_classes(app=nil)                                                                                                                                              
	  r = [app || Rack::Builder.parse_file(File.join(Dir.pwd, 'config.ru')).first]
	
	  while ((next_app = r.last.instance_variable_get(:@app)) != nil)
	    r << next_app
	  end
	
	  r.map{|e| e.instance_variable_defined?(:@app) ? e.class : e }
	end
	#app = Rack::Builder.parse_file('config.ru').first
	#puts middleware_classes(app).inspect
	
	
  
end
