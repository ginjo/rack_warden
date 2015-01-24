# RackWarden

RackWarden is a ruby gatekeeper mini-app providing authentication and user management for rack based apps. Protecting your entire application with only a few lines of code, RackWarden uses its own controllers, views, models, and database. You can also drop in your own views and layouts, specify your own database, and use your existing users table for seamless custom integration.

RackWarden is a Sinatra mini-app that uses Warden for authentication and DataMapper for database connections. It is based on the sinatra-warden-example at <https://github.com/sklise/sinatra-warden-example>.

RackWarden is a work-in-progress. The gemspec, the files, the code, and the documentation can and will change over time. Follow on github for the latest updates.


## Installation

In your Gemfile.

    gem 'rack_warden'

Then.

    $ bundle

Or install manually.

    $ gem install rack_warden

If you are using a database other than sqlite, and you want RackWarden to use that database as well, install the corresponding DataMapper database adapter. The dm-sqlite-adapter is included in the RackWarden gemspec.

    gem 'dm-mysql-adapter'
    gem 'dm-postgres-adapter'
    
See the [DataMapper](https://github.com/datamapper/dm-core/wiki/Adapters) site for more info on adapters. 

## Usage

A few simple steps will have your entire app protected.

### Sinatra

    class MySinatraApp < Sinatra::Base
      use RackWarden
    
      get "/" do
        erb "All routes are now protected"
      end
    end

### Rails

application.rb or environment.rb

    config.middleware.use RackWarden
    
    # All routes are now protected
    


## Configuration

RackWarden will look for a yaml configuration file named rack\_warden.yml in your project root or in your project-root/config/ directory. You can specify any of RackWarden's settings here.

    ---
    database: sqlite3:///usr/local/some_other_database.sqlite3.db
    layout: :'my_custom_layout.html.erb'


You an also pass configuration settings to RackWarden through the ```use``` method of your framework. The params hash of ```use``` will be translated directly to RackWarden's settings. In addition to RackWarden's specific configuration options, you can also pass standard Sinatra settings.

If you pass a block with the ```use``` method, the block will be evaluated in the context of the RackWarden::App class. Anything you do in that block is just as if you were writing code in the RackWarden::App class itself. While in the block, you also have access to the current instance of RackWarden::App.

    use RackWarden::App do |rack_warden_app_instance|
      set :some_setting, 'some_value'
    end
    
Note that with some frameworks, the RackWarden middleware instance will be lazy-loaded only when it is needed (usually with the first request). This is a function of the ruby framework you are using and is not under control of RackWarden. This means that some settings you pass with the ```use``` method (or block) may have 'missed the boat'. RackWarden tries to integrate these settings in lazy-loaded situations as best as it can. However, if you suspect your settings might not be taking, put your settings in the rack\_warden.yml config file. The config file will always be loaded with the RackWarden module.


## Configuration Options

Current list of settings specific to rack\_warden, with defaults.

    set :config_files, [ENV['RACK_WARDEN_CONFIG_FILE'], 'rack_warden.yml', 'config/rack_warden.yml'].compact.uniq
    set :layout, :'rw_layout.html'
    set :default_route, '/'
    set :exclude_from_return_to, 'login|new|create'
    set :repository_name, :default
    set :database_config => nil
    set :database_default =>  "sqlite3::memory:?cache=shared"
    set :recaptcha, Hash.new
    set :require_login, nil
    set :allow_public_signup, false
    set :logging, true
    set :log_path, "#{Dir.pwd}/log/rack_warden.#{settings.environment}.log"
    set :log_file, ($0[/rails|irb|ruby|rack|server/i] && development? ? $stdout : nil)
    set :log_level => ENV['RACK_WARDEN_LOG_LEVEL'] || (development? ? 'INFO' : 'WARN')
    set :logger, nil
    set :use_common_logger, false
    set :reset_logger, false
    set :sessions, nil # Will use parent app sessions. Pass in :key=>'something' to enable RW-specific sessions.
    set :user_table_name, nil
    set :views, File.expand_path("../views/", __FILE__) unless views

### :layout

A symbol representing a (Sinatra) layout file in any of the view paths.
    
    layout: :'rack_warden_layout.html'
    
### :default\_route

A Sinatra route to fall back on after logout, errors, or any redirect that has no specified route.

    default_route: '/'
    
### :database\_config

A database specification hash or url string.

    database_config: "sqlite:///Absolute/path/to/your/rack_warden.sqlite3.db"
    
    # or
    
    database_config: 
      adapter: mysql
      database: my_db_name
      username: root
      password: my_password
      host: 127.0.0.1
      port: 3306

### :require\_login

Parameters to pass to the before/before\_filter for require\_login.
So if your main app is Sinatra,

    require_login: /^\/admin/
    
is the same as

    class MySinatraApp
      require_login /^\/admin/
    end
    
which is the same as

    class MySinatraApp
      before /^\/admin/ do
        require_login
      end
    end
    
For Rails, you would be passing a hash of :only or :except keys.

    require_login: {:except => :index}
    
The default for :require\_login is nil, which means require login on every route or action.
To disable automatic activation of require\_login, pass it ```false```.

### :allow\_public\_signup

Allows public access to the account creation view & action.

    allow_public_signup: false
    
    
### :recaptcha

Settings for Google's recaptcha service. If these settings exist, recaptcha will be required on account creation and password reset/recover actions.

    :recaptcha => {
      :sitekey => '',
      :secret  => ''
    }



## Customization

### Views

RackWarden looks for templates at the top level of your views directory and in views/rack\_warden/ (if it exists) as a default. You can change or add to this with the ```:views``` setting.

    use RackWarden::App, :views => File.join(Dir.pwd, 'app/views/another_directory')
    
Or if you simply want RackWarden to wrap all of its views in your own custom layout, pass it a file path in the :layout parameter.

    use RackWarden::App, :layout => :'layouts/rack_warden_layout.html'
    
Remember that RackWarden is Sinatra, and any templates you pass must use Sinatra-specific code. For example, Sinatra uses ```url``` instead of Rails' ```url_for```. Also remember that template names in Sinatra must always be symbols. Have a look at the readme on Sinatra's web site for more details on Sinatra's DSL.


### Database

As a default, RackWarden will use a sqlite3 database created in your app's root. To use the database specified in your project, just pass ```:auto``` to the ```:database_config``` setting. Pass ```:file``` to set up a sqlite3 database in your app's working directory. Or pass your own custom database specification (a url or hash). If you use a database other than sqlite3, you will need to include the respective DataMapper extension gem in your Gemfile or in your manually installed gem list. For MySQL, use dm-mysql-adapter, for Postgres use dm-postgres-adapter. See the DataMapper site for more info on database adapters.
    
    # Database specification as a url
    database_config: 'sqlite3:///path/to/my/database.sqlite3.db'
    
    # Database specification as a hash
    database_config: {adapter: 'sqlite3', database: '/path/to/my/database.sqlite3.db'}
    
    # Use a remote MySQL database
    database_config: {adapter: 'mysql', username: 'will', password: 'mypass',
      host: 'somehost', database: 'my_database'}
    
    # Format for database urls
    #<adapter>://<username>:<password>@<host>:<port>/<database_name>

#### A note about DataMapper and ActiveRecord

ActiveRecord and DataMapper should be able to coexist in the same ruby process. Note that the database adapters for ActiveRecord are not the same as those for DataMapper. So for example, if you are using mysql, you will need the activerecord-mysql2-adapter for ActiveRecord (or mysql2 or mysql, if you're on older rails versions) and the dm-mysql-adapter for DataMapper.









