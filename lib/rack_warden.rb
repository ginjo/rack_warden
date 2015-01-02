require "sinatra/base"
require "sinatra/flash"
require 'bcrypt'
require 'data_mapper'
require 'warden'
require 'open-uri'

# gem 'data_mapper'
# gem 'dm-sqlite-adapter'
# gem 'warden'

# require "rack_warden/app"
# require "rack_warden/version"

module RackWarden
  autoload :App, 'rack_warden/app'
  autoload :User, "rack_warden/model"
  autoload :VERSION, "rack_warden/version"
  module Frameworks
    autoload :Base, 'rack_warden/framework_base'
    autoload :Sinatra, 'rack_warden/frameworks/sinatra'
    autoload :Rails, 'rack_warden/frameworks/rails'
  end
end
