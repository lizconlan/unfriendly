#encoding: utf-8

require 'yaml'
require 'oauth'
require 'json'
require 'logger'

class Twitter
  attr_reader :api_version

  LOGGER = Logger.new(STDOUT)

  def self.config
    @config ||= YAML::load(File.open './config/oauth.yml')
  end

  def self.oauth
    @oauth ||= OAuth::Consumer.new(
      config[:consumer_key],
      config[:consumer_secret],
      { :site => "https://api.twitter.com" })
  end
  
  def self.get_request_token(hostname)
    url = "http://#{hostname}/sign-in-with-twitter"
    oauth.get_request_token(:oauth_callback => url)
  end
  
  def initialize(token, secret, verifier, api_version="1.1")
    @api_version = api_version
    @access_token = get_access_token(token, secret, verifier)
  end
  
  def get(url)
    Twitter.oauth.request(:get, "/#{@api_version}/#{url}".squeeze("/"), @access_token, { :scheme => :query_string })
  end
  
  def post(url, post_data)
    data = CGI::escape(post_data)
    Twitter.oauth.request(:post, "/#{@api_version}/#{url}".squeeze("/"), @access_token, {}, data)
  end

  def get_friends_data(name, offset=nil)
    LOGGER.info("Getting a friend list from the Twitter API on behalf of #{name}")
    if offset
      cursor_string = "&cursor=#{offset}"
    else
      cursor_string = ""
    end

    begin
      response = get("friends/ids.json?screen_name=#{name}#{cursor_string}")
    rescue => e
      log_and_rethrow(e)
    end

    data = JSON.parse(response.body)
    if data["ids"].nil?
      LOGGER.error("unexpected response from Twitter - #{data.to_s}")
      raise "Twitter not co-operating"
    end
    data
  end

  def get_batch_user_info(ids)
    LOGGER.info("Looking up user data from the Twitter API on behalf of #{screen_name}")
    begin
      response = get("users/lookup.json?user_id=#{ids.join(",")}")
    rescue => e
      log_and_rethrow(e)
    end
    JSON.parse(response.body)
  end
  
  def screen_name
    @access_token.params[:screen_name]
  end
  
  def user_id
    @access_token.params[:user_id]
  end
  
  def log_and_rethrow(err)
    LOGGER.error("uncaught #{err} exception while handling connection: #{err.message}")
    LOGGER.error("Stack trace: #{backtrace.map {|l| "  #{l}\n"}.join}")
    raise err
  end
  
  
  private
  
  def get_access_token(token, secret, verifier)      
    request_token = OAuth::RequestToken.new(Twitter.oauth, token, secret)
    request_token.get_access_token(:oauth_verifier => verifier)
  end
end