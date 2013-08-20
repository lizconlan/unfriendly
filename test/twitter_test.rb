require './test/minitest_helper.rb'
require './lib/twitter'

class TwitterTest < MiniTest::Spec
  describe Twitter, "without hitting Twitter's API" do
    before do
      mock_config = YAML::load(%Q|
        :consumer_key: dummy_consumer_key
        :consumer_secret: dummy_consumer_secret
        :access_token: dummy_access_token
        :access_secret: dummy_access_secret
      |)
      Twitter.stub :config, mock_config do
        Twitter.config[:access_token].must_equal "dummy_access_token"
        Twitter.config[:consumer_secret].must_equal "dummy_consumer_secret"
      end
      
      @@oauth ||= Twitter.oauth
      @oauth = @@oauth
    end
    
    describe "class methods" do
      it "must return an OAuth::Consumer object when asked for oauth" do
        @oauth.must_be_instance_of OAuth::Consumer
      end
      
      it "must call oauth's get_request_token method when asked for get_request_token" do
        @oauth.expects("get_request_token")
        Twitter.get_request_token("localhost")
      end
    end
    
    describe "creating a new object" do
      it "must call OAuth::RequestToken.new if passed a verifier string" do
        mock_request_token = mock("request_token")
        mock_request_token.responds_like_instance_of(OAuth::RequestToken)
        mock_request_token.expects(:get_access_token).with(:oauth_verifier => "verifier").returns("fake_access_token")
        OAuth::RequestToken.expects(:new).returns(mock_request_token)
        
        twitter = Twitter.new("fake_token", "fake_secret", "verifier")
        twitter.must_be_instance_of(Twitter)
      end
      
      it "must call OAuth::AccessToken.from_hash if passed a hash" do
        twitter = Twitter.new("fake_token", "fake_secret", {:screen_name => "test", :twitter_id => "1234"})
        twitter.must_be_instance_of(Twitter)
      end
      
      it "must raise an error if passed anything else" do
        create_with_array = lambda { Twitter.new("fake_token", "fake_secret", ["this", "should", "fail"]) }
        create_with_array.must_raise RuntimeError
        error = create_with_array.call rescue $!
        error.message.must_equal "received Array, expected a String or a Hash"
      end
    end
    
    describe "in general" do
      before do
        unless defined?(@@twitter)
          mock_request_token = mock("request_token")
          mock_request_token.responds_like_instance_of(OAuth::RequestToken)
          @@fake_access_token = mock("access_token")
          @@fake_access_token.responds_like_instance_of(OAuth::AccessToken)
          mock_request_token.expects(:get_access_token).with(:oauth_verifier => "verifier").returns(@@fake_access_token)
          OAuth::RequestToken.expects(:new).returns(mock_request_token)
          @@twitter = Twitter.new("fake_token", "fake_secret", "verifier")
        end
        @twitter = @@twitter
        @fake_access_token = @@fake_access_token
      end
      
      it "must call OAuth.request when asked to get a Twitter url" do
        url = "/1.1/friends/ids.json?screen_name=test"
        @oauth.expects(:request).with(:get, url, @fake_access_token, { :scheme => :query_string })
        @twitter.get(url)
      end
      
      it "must retrieve the screen_name from the access_token when asked for screen_name" do
        @fake_access_token.expects(:params).returns({:screen_name => "test_user", :user_id => "1234"})
        @twitter.screen_name.must_equal("test_user")
      end
      
      it "must retrieve the user_id from the access_token when asked for user_id" do
        @fake_access_token.expects(:params).returns({:screen_name => "test_user", :user_id => "1234"})
        @twitter.user_id.must_equal("1234")
      end
    end
  end
end