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
    
  spec.add_dependency "backports"
  spec.add_dependency "bcrypt"
  spec.add_dependency "dry-types"
  spec.add_dependency "dry-struct"
  spec.add_dependency "mail"
  spec.add_dependency "multi_json"
  spec.add_dependency "omniauth"
  spec.add_dependency "rack-contrib"
  spec.add_dependency "rack-flash3"
  spec.add_dependency "rom-sql"
  spec.add_dependency "rom-repository"
  spec.add_dependency "sinatra"
  spec.add_dependency "sinatra-contrib"
  spec.add_dependency "warden"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "thin"
  spec.add_development_dependency "tux"
end
