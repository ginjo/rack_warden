::RACK_WARDEN_STANDALONE = true

require 'bundler'

Bundler.require

require File.expand_path('../lib/rack_warden', __FILE__)

map ENV['BASE_URI'] || '/' do
	run RackWarden::App
end