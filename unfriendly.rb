require 'sinatra'
require 'sinatra/flash'
require 'mongoid'

class Unfriendly < Sinatra::Base
  register Sinatra::Flash
  enable :sessions
  set :session_secret, ENV["session_secret"] || "secret string"
  
  require './models/user'
  require './lib/twitter'
  
  # start the server if ruby file executed directly
  run! if app_file == $0
  
  Mongoid.load!("./config/mongo.yml")
  
  get "/" do
    if session[:twitter]
      @twitter = session[:twitter]
      #raise session[:access_token].params.inspect
      
      response = @twitter.get("/1.1/friends/ids.json?screen_name=#{session[:user_name]}")
      raise JSON.parse(response.body).inspect
    end
      
    haml(:index)
  end
  
  get "/twitter_login/?" do
    request_token = Twitter.get_request_token(request.host_with_port.gsub(/\:80$/, ""))
    session[:token] = request_token.token
    session[:secret] = request_token.secret
    
    redirect request_token.authorize_url
  end
  
  get "/sign-in-with-twitter/?" do
    @twitter = Twitter.new(session[:token], session[:secret], params[:oauth_verifier])
    session[:twitter] = @twitter
    session[:user_name] = @twitter.screen_name
    session[:user_id] = @twitter.user_id
    redirect "/"
  end
  
  get "/logout/?" do
    session.clear
    flash.next[:success] =  "You've logged out"
    redirect '/'
  end
  
  get "/check/?" do
    redirect "/login" unless session[:user_id]
    
    user = User.where(email: supplied_email).first
    redirect "/login" unless user
  end
end