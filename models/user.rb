require 'mongoid'

class User
  include Enumerable
  include Mongoid::Document
  embeds_many :follower_changes
  
  field :email, type: String
  field :screen_name, type: String
  field :twitter_id, type: String
  field :verifier, type: String
  field :friend_ids, type: Array
end

class FollowerChange
  include Mongoid::Document
  embedded_in :user
  
  field :followed, type: Array
  field :unfollowed, type: Array
  field :check_date, type: DateTime
end