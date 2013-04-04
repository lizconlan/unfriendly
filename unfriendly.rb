require 'sinatra'
require 'sinatra/flash'
require 'mongoid'
require 'bcrypt'

class Unfriendly < Sinatra::Base
  register Sinatra::Flash
  enable :sessions
  set :session_secret, ENV["session_secret"] || "secret string"
  
  require './models/user'
  
  # start the server if ruby file executed directly
  run! if app_file == $0
  
  Mongoid.load!("./config/mongo.yml")
  
  get "/" do
    haml(:index)
  end
  
  get "/signup/?" do
    haml(:form)
  end
  
  post "/signup" do
    supplied_email = params[:email]
    supplied_password = params[:password]
    matching = User.where(email: supplied_email)
    if matching.count > 0
      flash.now[:alert] = "Email already registered, try a different one"
      haml(:form)
    else matching.count > 0
      password = BCrypt::Password.create(supplied_password)
      user = User.create(:email => supplied_email, :password => password)
      user.save!
      flash.next[:success] =  "Welcome registered user. Please login :)"
      redirect "/login"
    end
  end
  
  get "/login/?" do
    haml(:form)
  end
  
  post "/login" do
    supplied_email = params[:email]
    supplied_password = params[:password]
    
    user = User.where(email: supplied_email).first
    if user
      user_hash = BCrypt::Password.new(user.password)
      if user_hash == supplied_password
        session[:user_id] = user.id
        flash.next[:success] = "Woot! Hello :)"
        redirect "/"
      else
        flash.now[:alert] = "Incorrect username or password"
      end
    else
      flash.now[:alert] = "Incorrect username or password"
    end
    haml(:form)
  end
  
  get "/logout/?" do
    session[:user_id] = nil
    flash.next[:success] =  "You've logged out"
    redirect '/'
  end
  
  get "/check/?" do
    redirect "/login" unless session[:user_id]
    
    user = User.where(email: supplied_email).first
    redirect "/login" unless user
  end
end