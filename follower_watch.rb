require 'bundler'
Bundler.setup

require 'sinatra/base'
require 'mongo_mapper'
require 'bcrypt'

class FollowerWatch < Sinatra::Base
  require './lib/twitter'
  
  # start the server if ruby file executed directly
  run! if app_file == $0
  
  MONGO_URL = ENV['MONGO_URL'] || YAML::load(File.read("config/mongo.yml"))[:mongo_url]
  env = {}
  MongoMapper.config = { env => {'uri' => MONGO_URL} }
  MongoMapper.connect(env)
  
  get "/" do
    "hi!"
  end
  
  get "/signup/?" do
  end
  
  post "/signup" do
    supplied_password = params[:password]
    password = BCrypt::Password.create(supplied_password)
  end
  
  get "/login/?" do
    supplied_password = params[:password]
    password_to_check = BCrypt::Password.create(supplied_password)
  end
  
  post "/login" do
  end
  
  get "/check/?" do
  end
end