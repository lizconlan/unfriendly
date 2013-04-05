require 'mongoid'

class User
  include Mongoid::Document
  
  field :email, type: String
  field :screen_name, type: String
  field :twitter_id, type: String
  field :verifier, type: String
  field :friend_ids, type: Array
  field :archived_ids, type: Array #one set only!
  field :last_check_date, type: DateTime
  field :archive_store_date, type: DateTime
  
  def twitter_list
    @twitter_list || set_twitter_list()
  end
  
  def live_list
    #@twitterlist.get_list()
  end
  
  def unfollowed
  end
  
  def added
  end
  
  private
    def set_twitter_list
    end
    
    def diff
      #diff between live_list and stored_list
      #call out to @twitterlist.lookup_ids?
    end
end