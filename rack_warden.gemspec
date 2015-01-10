# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack_warden/version'

Gem::Specification.new do |spec|
  spec.name          = "rack_warden"
  spec.version       = RackWarden::VERSION
  spec.authors       = ["William Richardson"]
  spec.email         = ["wbr@mac.com"]
  spec.summary       = %q{Authentication and user management for any rack-based framework}
  spec.description   = %q{A warden/sinatra mini-app providing authentication and user management for any rack-based framework.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
    
  spec.add_dependency "sinatra"
  spec.add_dependency "sinatra-flash"
  spec.add_dependency "bcrypt"
  spec.add_dependency "data_mapper"
  spec.add_dependency "dm-sqlite-adapter"
  spec.add_dependency "warden"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
