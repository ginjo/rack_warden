# RackWarden

RackWarden is a rack middleware mini-app that provides user authentication and management to any rack-based app (currently supports Sinatra and Rails, with more on the way). This project is in its infancy. It is currently a great starter to get you going with plug-in authentication for your ruby app. Over time it will grow into a more fully featured package while maintaining a focus on simplicity, modularity, and transparency.

RackWarden uses Sinatra for the mini-app, Warden for authentication, and DataMapper for database connections. It is based on the sinatra-warden-example at https://github.com/sklise/sinatra-warden-example. If you are new to warden or Sinatra, I highly recommend downloading and experimenting with that example.

My goal in developing this software is to have drop-in authentication containing most of the features you see in user/account management sections of a typical web site. But I don't want to be strapped by this module in any of my projects, so it must be customizable. Or rather, overridable. The basics of this flexibility are already in place, and it will be a central theme throughout. See below for examples on overriding and customizing RackWarden.


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
		


## Configuration

Pass configuration settings to RackWarden through your ``use`` method. The params hash will be translated directly to the app's settings. You can currently specify :database, :views, and :default_route. You can also specify any of the standard Sinatra settings, like :views.

If you pass a block with the ``use`` method, the block will be evaluated in the context of the RackWarden::App class. Anything you do in that block is just as if you were writing code in the app class itself. While in the block, you also have access to two relevant objects.

		use RackWarden::App do |rack_warden_app_instance, parent_app_instance|
			set :somesetting, 'some_value'
		end


## Customization

To customize RackWarden for your specific project, you can set :views to point to a directory within your project. Then create templates that match the names of RackWarden templates, and they will be picked up and rendered. RackWarden looks for templates at the top level of your views directory as a default. You can change or add to this when you define the middleware in your project.

		use RackWarden::App, :views => File.join(Dir.pwd, 'app/views/rack_warden')
		
Or if you simply want RackWarden to use your own custom layout, pass it a file path in the :layout parameter.

		use RackWarden::App, :layout => :'layouts/rack_warden_layout.html'
		
Just remember that RackWarden is Sinatra, and any templates you pass must use Sinatra-specific code. For example, Sinatra uses ``url`` instead of Rails' ``url_for``. Also remember that template names in Sinatra must always be symbols.

Another way to customize RackWarden is to override its classes and methods, as you would with any other ruby code.

And if you want to customize RackWarden more extensively, you can always download the source from github and directly modify the app file and templates. Then point to this modified gem in your project Gemfile.

		gem 'rack_warden', :path => "../RackWarden/"






