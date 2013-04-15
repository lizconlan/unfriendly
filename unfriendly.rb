require 'sinatra'
require 'sinatra/flash'
require 'mongoid'
require 'set'

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
    session[:token] = nil
    session[:secret] = nil
    session[:twitter] = @twitter
    redirect "/check"
  end
  
  get "/logout/?" do
    session.clear
    flash.next[:success] =  "You've logged out"
    redirect '/'
  end
  
  get "/check/?" do
    redirect "/twitter_login" unless session[:twitter]
    
    @twitter = session[:twitter]
    @user = User.find_or_create_by(:twitter_id => @twitter.user_id, :screen_name => @twitter.screen_name)
    
    @current_list = get_friends(@twitter.screen_name)
    
    if @user.friend_ids.nil? or @user.friend_ids.empty?
      #new user, hello!
      @user.friend_ids = @current_list
      @user.save
    else
      #welcome back, let's check things
      unless @user.friend_ids == @current_list
        change_data = analyse_changes(Set.new(@user.friend_ids), Set.new(@current_list))
        @followed = change_data[:followed]
        @unfollowed = change_data[:unfollowed]
        
        if @user.following_changes.empty? or (@followed != @user.following_changes.last.followed or @unfollowed != @user.following_changes.last.unfollowed)
          @user.friend_ids = @current_list
          @user.save
          
          @change = FollowingChange.new
          @change.followed = @followed
          @change.unfollowed = @unfollowed
          @change.check_date = Time.now()
          @user.following_changes << @change
        else
          @change = @user.following_changes.last
          @followed = @change.followed
          @unfollowed = @change.unfollowed
        end
      else
        @change = @user.following_changes.last
        if @change
          @followed = @change.followed
          @unfollowed = @change.unfollowed
        end
      end
      
      @followed_accounts = process_follower_ids(@followed) if @followed && @followed.count > 0
      @unfollowed_accounts = process_follower_ids(@unfollowed) if @unfollowed && @unfollowed.count > 0
    end
    
    haml(:check)
  end
  
  private
    def get_friends(screen_name)
      response = @twitter.get("/1.1/friends/ids.json?screen_name=#{screen_name}")
      data = JSON.parse(response.body)
      list = data["ids"]

      # go again (and again, and again...) if there are more things still to fetch
      # default retrieval limit per request is 5,000 (correct at time of writing)
      while data["next_cursor_str"] != "0"
        response = @twitter.get("/1.1/friends/ids.json?screen_name=#{screen_name}&cursor=#{data["next_cursor_str"]}")
        data = JSON.parse(response.body)
        list += data["ids"]
      end
      list
    end
    
    def process_follower_ids(id_list)
      data = []
      id_list.each_slice(100) do |batch|
        response = @twitter.get("/1.1/users/lookup.json?user_id=#{batch.join(",")}")
        data += JSON.parse(response.body)
      end
      data.map{ |x| {:screen_name => x["screen_name"], :name => x["name"], :profile_image => x["profile_image_url"], :protected => x["protected"]}}
    end
    
    def analyse_changes(s1, s2)
      followed = []
      unfollowed = []
      diff = (s1^s2).to_a
      diff.each do |change|
        if s1.include?(change)
          unfollowed << change
        else
          followed << change
        end
      end
      {:followed => followed, :unfollowed => unfollowed}
    end
end