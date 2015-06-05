#encoding: utf-8

require 'sinatra'
require 'mongoid'
require 'set'
require 'logger'

class Unfriendly < Sinatra::Base
  enable :sessions
  set :session_secret, ENV["session_secret"] || "secret string"

  require './models/user'
  require './lib/twitter'

  # start the server if ruby file executed directly
  run! if app_file == $0

  LOGGER = Logger.new(STDOUT)

  Mongoid.load!("./config/mongo.yml")

  get "/" do
    redirect "check" if session[:twitter]
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
    default_session_params

    @user = User.find_or_create_by(:twitter_id => @twitter.user_id, :screen_name => @twitter.screen_name)

    redirect "/check"
  end

  get "/logout/?" do
    session.clear
    redirect '/'
  end

  get "/check/?" do
    redirect "/twitter_login" unless session[:twitter]

    @twitter = session[:twitter]
    @user = User.find_or_create_by(:twitter_id => @twitter.user_id, :screen_name => @twitter.screen_name)
    
    @current_list = current_list_for_user(@user)

    if @current_list
      process_user_data
    end
    haml(:check)
  end

  private

  def default_session_params
    session[:token] = nil
    session[:secret] = nil
    session[:twitter] = @twitter
    session[:verifier] = params[:oauth_verifier]
  end

  def get_friends_list(screen_name)
    data = @twitter.get_friends_data(screen_name)
    list = data["ids"]

    while data["next_cursor_str"] and data["next_cursor_str"] != "0"
      data = @twitter.get_friends_data(screen_name, data["next_cursor_str"])
      list += data["ids"]
    end
    list
  end

  def process_follower_ids(id_list)
    data = []
    id_list.each_slice(100) do |batch|
      js = @twitter.get_batch_user_info(batch)

      if js.class == Hash
        data += [js]
      else
        data += js
      end
    end
    data.map{|x| {
      :screen_name => x["screen_name"],
      :name => x["name"],
      :profile_image => x["profile_image_url"],
      :protected => x["protected"]
    }}
  end

  def current_list_for_user(user)
    if user.following_changes \
        and !user.following_changes.empty? \
        and user.following_changes.last.check_date.strftime("%Y-%m-%d") == Time.now.strftime("%Y-%m-%d")
      return list = user.friend_ids
    else
      begin
        return get_friends_list(user.screen_name)
      rescue
        return nil
      end
    end
  end
  
  def process_user_data
    if @user.new?
      @user.friend_ids = @current_list
      @user.save
    else
      crunch_data_for_returning_user
      @followed_accounts = process_follower_ids(@followed) if @followed && @followed.count > 0
      @unfollowed_accounts = process_follower_ids(@unfollowed) if @unfollowed && @unfollowed.count > 0
    end
  end
  
  def crunch_data_for_returning_user
    changes = @user.following_changes.dup

    # nothing's changed, show the old data
    if @user.friend_ids == @current_list
      restore_previous_change(changes)
    else
      # change ahoy!
      change_data = analyze_changes(Set.new(@user.friend_ids), Set.new(@current_list))
      @followed = change_data[:followed]
      @unfollowed = change_data[:unfollowed]

      if follower_info_changed?
        @user.save
        @prev_change = changes.pop
        store_change
      else
        restore_previous_change(changes)
      end
    end
  end

  def analyze_changes(s1, s2)
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
  
  def follower_info_changed?
    @user.following_changes.empty? or \
        (@followed != @user.following_changes.last.followed \
        or @unfollowed != @user.following_changes.last.unfollowed)
  end
  
  def store_change
    @change = FollowingChange.new
    @change.followed = @followed
    @change.unfollowed = @unfollowed
    @change.check_date = Time.now()
    @user.following_changes << @change
  end
  
  def restore_previous_change(changes)
    @change = changes.pop
    @prev_change = changes.pop
    if @change
      @followed = @change.followed
      @unfollowed = @change.unfollowed
    end
  end
end
