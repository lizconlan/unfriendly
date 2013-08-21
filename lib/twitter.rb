require 'yaml'
require 'oauth'

class Twitter 
  attr_reader :api_version
  
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
  
  def screen_name
    @access_token.params[:screen_name]
  end
  
  def user_id
    @access_token.params[:user_id]
  end
  
  
  private
  
  def get_access_token(token, secret, verifier)      
    request_token = OAuth::RequestToken.new(Twitter.oauth, token, secret)
    request_token.get_access_token(:oauth_verifier => verifier)
  end
end