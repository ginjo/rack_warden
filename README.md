# RackWarden

RackWarden is a rack middleware mini-app that provides user authentication and management to any rack-based app. RackWarden uses Sinatra for the mini-app, Warden for authentication, and DataMapper for database connections.

RackWarden is in its infancy. It's currently a great starter to get you going with plug-in authentication for your ruby app. Over time it will grow into a more fully featured package while maintaining a focus on simplicity and transparency.

RackWarden is based on the sinatra-warden-example at https://github.com/sklise/sinatra-warden-example. If you're new to warden and/or sinatra, I highly recommend downloading and experimenting with that example.


## Installation

In your Gemfile:

		gem 'rack_warden'

Then:

    $ bundle

Or install manually:

    $ gem install rack_warden


## Usage

A few simple steps will have your entire app protected.

### Sinatra

		class MySinatraApp < Sinatra::Base
			use RackWarden::App
			
			before do
				require_login
			end
		
			get "/" do
				erb "All routes are now protected"
			end
		end

### Rails

application.rb or environment.rb

		config.middleware.use RackWarden::App
		
application-controller.rb

		before_filter :require_login
		
### Others...

## How it works

...

## Customizing

...


