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
  
  helpers do
    def format_screen_name_array(arr)
      output = []
      arr.each_with_index do |name, index|
        output << %Q|<a href="http://twitter.com/#{name}">@#{name}</a>|
        case index
        when arr.size-1
          #last item, add no extras
        when arr.size-2
          output << " and "
        else
          output << ", "
        end
      end
      output.join("")
    end
  end
  
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
    
    response = @twitter.get("/1.1/friends/ids.json?screen_name=#{@twitter.screen_name}")
    data = JSON.parse(response.body)
    @current_list = data["ids"]
    
    if @user.friend_ids.nil? or @user.friend_ids.empty?
      #new user, hello!
      @user.friend_ids = @current_list
      @user.save!
    else
      #welcome back, let's check things
      unless @user.friend_ids == @current_list
        change_data = analyse_changes(Set.new(@user.friend_ids), Set.new(@current_list))
        @followed = change_data[:followed]
        @unfollowed = change_data[:unfollowed]
        
        if @user.following_changes.empty? or (@followed != @user.following_changes.last.followed or @unfollowed != @user.following_changes.last.unfollowed)
          @user.friend_ids = @current_list
          @user.update
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
      
      if @followed && @followed.count > 0
        response = @twitter.get("/1.1/users/lookup.json?user_id=#{@followed.join(",")}")
        data = JSON.parse(response.body)
        
        @followed_screen_names = data.map{ |x| x["screen_name"]}
      end
      
      if @unfollowed && @unfollowed.count > 0
        response = @twitter.get("/1.1/users/lookup.json?user_id=#{@unfollowed.join(",")}")
        data = JSON.parse(response.body)
        
        @unfollowed_screen_names = data.map{ |x| x["screen_name"]}
      end
    end
    
    haml(:check)
  end
  
  private
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