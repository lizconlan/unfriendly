require 'sinatra/base'

require 'bundler'
Bundler.setup

class FollowerWatch < Sinatra::Base
  require './lib/twitter'
  
  # start the server if ruby file executed directly
  run! if app_file == $0
  
  get "/" do
    "hi!"
  end
  
  get "/test/?" do
  end
end