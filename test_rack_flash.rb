require 'sinatra/base'

require 'rack-flash'

class TestRackFlash < Sinatra::Base
  
  set :session, :key=>"test-rack-flash"
  use Rack::Flash #, :accessorize=>:rwarden
  
  get "/" do
    # THIS CRASHES
    #flash.rwarden
    #request.cookies['rack.session'].inspect
  end
  
  run!
end