require "sinatra/base"
require "sinatra/flash"
require 'bcrypt'
require 'data_mapper'
require 'warden'
require 'open-uri'

# gem 'data_mapper'
# gem 'dm-sqlite-adapter'
# gem 'warden'

require "rack_warden/app"
require "rack_warden/model"
require "rack_warden/version"

module RackWarden
  # Your code goes here...
end
