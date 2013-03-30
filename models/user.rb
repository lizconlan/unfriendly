require 'mongo_mapper'

class User
  include MongoMapper::Document
  
  key :email, String
  key :password, String
  key :friend_ids, Array
  key :archived_ids, Array #one set only!
  key :last_check_date, DateTime
  key :archive_store_date, DateTime
  
  def initialize
    @twitterlist = TwitterList.new
  end
  
  def live_list
    @twitterlist.get_list()
  end
  
  def unfollowed
  end
  
  def added
  end
  
  private
    def diff
      #diff between live_list and stored_list
      #call out to @twitterlist.lookup_ids?
    end
    
end