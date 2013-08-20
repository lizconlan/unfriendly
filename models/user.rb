#encoding: utf-8

require 'mongoid'

class User
  include Mongoid::Document
  embeds_many :following_changes
  
  field :screen_name, type: String
  field :twitter_id, type: String
  field :email, type: String
  field :friend_ids, type: Array
end

class FollowingChange
  include Mongoid::Document
  embedded_in :user
  
  field :followed, type: Array
  field :unfollowed, type: Array
  field :check_date, type: DateTime
end