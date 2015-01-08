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
  
end
