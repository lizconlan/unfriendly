require 'json'
require 'yaml'
require 'rest-client'
require 'base64'

class TwitterList
  def initialize
    config = YAML::load(File.open './../config/oauth.yml')
    
    credentials = Base64.encode64("#{CGI.escape(config[:consumer_key])}:#{CGI.escape(config[:consumer_secret])}")
    
    response = RestClient.post 'https://api.twitter.com/oauth2/token', "grant_type=client_credentials", {:authorization => "Basic #{credentials.gsub("\n", "")}", :content_type => "application/x-www-form-urlencoded;charset=UTF-8"}
    content = JSON.parse(response)
    @bearer_token = content["access_token"]
  end
  
  def get_list(screen_name)
    #e.g. https://dev.twitter.com/docs/api/1.1/get/friends/ids
    result = RestClient.get "https://api.twitter.com/1.1/friends/ids.json?screen_name=#{screen_name}", {:authorization => "Bearer #{@bearer_token}"}
    content = JSON.parse(response)
    content["ids"]
  end
  
  def lookup_ids(screen_name, list)
    #do a lookup of the missing (+added?!) ids with https://api.twitter.com/1.1/users/lookup.json - https://dev.twitter.com/docs/api/1.1/get/users/lookup
  end
end