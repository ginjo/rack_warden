::RACK_WARDEN_STANDALONE = true

require 'bundler'

Bundler.require

require File.expand_path('../lib/rack_warden', __FILE__)

map ENV['BASE_URI'] || '/' do
	RackWarden::App.set :sessions, :key=>'_rack_warden'
	run RackWarden::App
end