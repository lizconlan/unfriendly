class User #< ActiveRecord:: (?)
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