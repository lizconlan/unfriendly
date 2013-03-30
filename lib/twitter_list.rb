require 'oauth'
require 'json'
require 'rest-client'

class TwitterList
  def initialize()
    #get the token etc, etc to get OAuth set up (unless that ends up being delegated to something else)
  end
  
  def get_list(screen_name)
    #e.g. https://dev.twitter.com/docs/api/1.1/get/friends/ids
    result = RestClient.get("https://api.twitter.com/1.1/friends/ids.json?screen_name=#{screen_name}")
  end
  
  def lookup_ids(screen_name, list)
    #do a lookup of the missing (+added?!) ids with https://api.twitter.com/1.1/users/lookup.json - https://dev.twitter.com/docs/api/1.1/get/users/lookup
  end
end