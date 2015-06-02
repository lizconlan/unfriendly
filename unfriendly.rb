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
    session[:token] = nil
    session[:secret] = nil
    session[:twitter] = @twitter
    session[:verifier] = params[:oauth_verifier]

    @user = User.find_or_create_by(:twitter_id => @twitter.user_id, :screen_name => @twitter.screen_name)
    @user.save

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

    if @user.following_changes \
        and !@user.following_changes.empty? \
        and @user.following_changes.last.check_date.strftime("%Y-%m-%d") == Time.now.strftime("%Y-%m-%d")
      @current_list = @user.friend_ids
    else
      begin
        @current_list = get_friends(@twitter.screen_name)
      rescue
        @current_list = nil
      end
    end

    if @current_list
      if @user.friend_ids.nil? or @user.friend_ids.empty?
        #new user, hello!
        @user.friend_ids = @current_list
        @user.save
      else
        #welcome back, let's check things
        changes = @user.following_changes.dup
        unless @user.friend_ids == @current_list
          change_data = analyse_changes(Set.new(@user.friend_ids), Set.new(@current_list))
          @followed = change_data[:followed]
          @unfollowed = change_data[:unfollowed]

          if @user.following_changes.empty? \
              or (@followed != @user.following_changes.last.followed \
              or @unfollowed != @user.following_changes.last.unfollowed)
            @user.save

            @prev_change = changes.pop

            @change = FollowingChange.new
            @change.followed = @followed
            @change.unfollowed = @unfollowed
            @change.check_date = Time.now()
            @user.following_changes << @change
          else
            @change = changes.pop
            @prev_change = changes.pop
            @followed = @change.followed
            @unfollowed = @change.unfollowed
          end
        else
          @change = changes.pop
          @prev_change = changes.pop
          if @change
            @followed = @change.followed
            @unfollowed = @change.unfollowed
          end
        end

        begin
          @followed_accounts = process_follower_ids(@followed) if @followed && @followed.count > 0
        rescue
          @followed_accounts = "error"
        end

        begin
          @unfollowed_accounts = process_follower_ids(@unfollowed) if @unfollowed && @unfollowed.count > 0
        rescue
          @unfolowed_accounts = "error"
        end
      end
    end
    haml(:check)
  end

  private
    def get_friends(screen_name)
      LOGGER.info("Getting a friend list from the Twitter API on behalf of #{screen_name}")
      begin
        response = @twitter.get("friends/ids.json?screen_name=#{screen_name}")
      rescue => e
        log_and_rethrow(e)
      end

      data = JSON.parse(response.body)
      list = data["ids"]
      if list.nil?
        LOGGER.error("unexpected response from Twitter - #{data.to_s}")
        raise "Twitter not co-operating"
      end

      # go again (and again, and again...) if there are more things still to fetch
      # default retrieval limit per request is 5,000 (correct at time of writing)
      while data["next_cursor_str"] and data["next_cursor_str"] != "0"
        LOGGER.info("Getting a friend list from the Twitter API on behalf of #{screen_name}")
        begin
          response = @twitter.get("friends/ids.json?screen_name=#{screen_name}&cursor=#{data["next_cursor_str"]}")
        rescue => e
          log_and_rethrow(e)
        end

        data = JSON.parse(response.body)
        if data["ids"].nil?
          LOGGER.error("unexpected response from Twitter - #{data.to_s}")
          raise "Twitter not co-operating"
        end
        list += data["ids"]
      end
      list
    end

    def process_follower_ids(id_list)
      data = []
      id_list.each_slice(100) do |batch|
        LOGGER.info("Looking up user data from the Twitter API on behalf of #{@user.screen_name}")
        begin
          response = @twitter.get("users/lookup.json?user_id=#{batch.join(",")}")
        rescue => e
          log_and_rethrow(e)
        end

        js = JSON.parse(response.body)
        if js.class == Hash
          data += [js]
        else
          data += js
        end
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

    def log_and_rethrow(err)
      LOGGER.error("uncaught #{err} exception while handling connection: #{err.message}")
      LOGGER.error("Stack trace: #{backtrace.map {|l| "  #{l}\n"}.join}")
      raise err
    end
end