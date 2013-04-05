require 'yaml'
require 'oauth'

class Twitter  
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
  
  def initialize(token, secret, verifier)
    @access_token = get_access_token(token, secret, verifier)
  end
  
  def get(url)
    Twitter.oauth.request(:get, url, @access_token, { :scheme => :query_string })
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