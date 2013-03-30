require 'mongoid'

class User
  include Mongoid::Document
  
  field :email, type: String
  field :password, type: String
  field :friend_ids, type: Array
  field :archived_ids, type: Array #one set only!
  field :last_check_date, type: DateTime
  field :archive_store_date, type: DateTime
  
  def live_list
    #@twitterlist.get_list()
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