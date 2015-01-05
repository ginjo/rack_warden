# RackWarden

RackWarden is a rack middleware mini-app that provides user authentication and management to any rack-based app (currently supports Sinatra and Rails, with more on the way). This project is in its infancy. It is currently a great starter to get you going with plug-in authentication for your ruby app. Over time it will grow into a more fully featured package while maintaining a focus on simplicity, modularity, and transparency.

RackWarden uses Sinatra for the mini-app, Warden for authentication, and DataMapper for database connections. It is based on the sinatra-warden-example at https://github.com/sklise/sinatra-warden-example. If you are new to Warden or Sinatra, I highly recommend downloading and experimenting with that example.

My goal in developing this software is to have drop-in authentication containing most of the features you see in user/account management sections of a typical web site. But I don't want to be strapped by this module in any of my projects, so it must be customizable. Or rather, overridable. The basics of this flexibility are already in place, and it will be a central theme throughout. See below for examples on overriding and customizing RackWarden.

Please note that RackWarden is a work-in-progress. The gemspec, the files, the code, and the documentation can and will change over time. Follow on github for the latest fixes, changes, and developments.

## What Does it Do?

RackWarden acts as a self-sufficient gatekeeper for your ruby web app. Once you enable RackWarden in your rack-based project, all routes/actions in your project will require a login and will redirect browsers to an authentication page. RackWarden provides its own view & layout templates to facilitate user authentication. RackWarden also provides it's own tables to store user data.

Once RackWarden authenticates a user, it gets out of the way, and the user is returned to your application. RackWarden also provides a number of user management tools for common actions like creating, updating, and deleting users.

Most of the RackWarden features can be customized. You can override the views, the database, the actions, and even the authentication logic with your own templates and code. The easiest (and possibly the most dramatic) customization is to provide RackWarden with your own layout template, giving RackWarden the look-and-feel of your own application.


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
    
      get "/" do
        erb "All routes are now protected"
      end
    end

### Rails

application.rb or environment.rb

    config.middleware.use RackWarden::App
    
    # All routes are now protected
    


## Configuration

RackWarden will look for a configuration file named rack\_warden.yml in your project root or in your project/config/ directory. 

		---
		database: sqlite3:///usr/local/some_other_database.sqlite3.db
		layout: :'my_custom_layout.html.erb'


You an also pass configuration settings to RackWarden through the ```use``` method of your framework. The params hash of ```use``` will be translated directly to RackWarden's settings. In addition to RackWarden's specific configuration options, you can also pass in any standard Sinatra settings.

If you pass a block with the ```use``` method, the block will be evaluated in the context of the RackWarden::App class. Anything you do in that block is just as if you were writing code in the app class itself. While in the block, you also have access to the current instance of RackWarden::App and the current instance of the parent app.

    use RackWarden::App do |rack_warden_app_instance, parent_app_instance|
      set :somesetting, 'some_value'
    end
		

## Configuration Options

Current list of settings specific to rack\_warden, with defaults.

### :layout

A symbol representing a layout file in any of the view paths.
    
    layout: :'rack_warden_layout.html'
    
### :default\_route

A Sinatra route to fall back on after logout, errors, or any action that has no specified route.

    default_route: '/'
    
### :database\_config

A database specification hash or or url string.

    database_config: "sqlite:///Absolute/path/to/your/rack_warden.sqlite3.db"
    
    # or
    
    database_config: 
      adapter: mysql2
      encoding: utf8
      database: my_db_name
      username: root
      password: my_password
      host: 127.0.0.1
      port: 3306

### :require\_login

Parameters to pass to the before/before\_filter for require\_login.
So if you're main app is Sinatra,

    require_login: /^\/.+/
    
is the same as

    class MySinatraApp
      require_login /^\/.+/
    end
    
which is the same as

    class MySinatraApp
      before /^\/.+/ do
        require_login
      end
    end
    
For Rails, you would be passing a hash of :only or :except keys.

    require_login:
      except: :index
    
The default for :require\_login is nil, which means require login on every route or action.
To disable automatic activation of require\_login, pass it ```false```.

### :allow\_public\_signup

Allows public access to the account creation view & action.

    allow_public_signup: false
    
    
### :recaptcha

Settings for Google's recaptcha service

    :recaptcha => {
      :sitekey => '',
      :secret  => ''
    }

### :log\_path

		File.join(Dir.pwd, 'log', 'rack_warden.log')

## Customization

### Views

To customize RackWarden for your specific project, you can set :views to point to a directory within your project. Then create templates that match the names of RackWarden templates, and they will be picked up and rendered. RackWarden looks for templates at the top level of your views directory as a default. You can change or add to this when you define the middleware in your project.

Update: also looks in views/rack\_warden/ for view templates.

    use RackWarden::App, :views => File.join(Dir.pwd, 'app/views/another_directory')
    
Or if you simply want RackWarden to use your own custom layout, pass it a file path in the :layout parameter.

    use RackWarden::App, :layout => :'layouts/rack_warden_layout.html'
    
Just remember that RackWarden is Sinatra, and any templates you pass must use Sinatra-specific code. For example, Sinatra uses ```url``` instead of Rails' ```url_for```. Also remember that template names in Sinatra must always be symbols. Have a look at the readme on Sinatra's web site for more details on Sinatra's DSL.


### Database

As a default, RackWarden will use the database specified in your project. You can also pass a database specification with the ```:database_config``` setting.
		
		# As a url
		database_config: 'sqlite3:///path/to/my/database.sqlite3.db'
		
		# As a hash
		database_config: {adapter: 'sqlite3', database: '/path/to/my/database.sqlite3.db'}
		
If your project has no database, or if you pass ```false``` to the ```:database_config``` setting, RackWarden will create its own database in the working directory as 'rack_warden.sqlite3.db'.








