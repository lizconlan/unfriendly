require 'yaml'
require 'oauth'

class Twitter 
  attr_reader :api_version
  
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
  
  def initialize(token, secret, input, api_version="1.1")
    @api_version = api_version
    if input.is_a?(String)
      @access_token = get_access_token(token, secret, input)
    elsif input.is_a?(Hash)
      token_yaml = token_template.dup
      token_yaml.gsub!("_TOKEN_", Twitter.config[:access_token])
      token_yaml.gsub!("_SECRET_", Twitter.config[:access_secret])
      token_yaml.gsub!("CONSUMER_KEY", Twitter.config[:consumer_key])
      token_yaml.gsub!("CONSUMER_SECRET", Twitter.config[:consumer_secret])
      token_yaml.gsub!("USER_ID", "'#{input[:twitter_id]}'")
      token_yaml.gsub!("SCREEN_NAME", input[:screen_name])
      
      @access_token = YAML::load(token_yaml)
    else
      raise "received #{input.class}, expected a String or a Hash"
    end
  end
  
  def get(url)
    Twitter.oauth.request(:get, "/#{@api_version}/#{url}".squeeze("//"), @access_token, { :scheme => :query_string })
  end
  
  def post(url, post_data)
    Twitter.oauth.request(:post, "/#{@api_version}/#{url}".squeeze("//"), @access_token, {}, post_data)
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
    
    def token_template
      "--- !ruby/object:OAuth::AccessToken\ntoken: _TOKEN_\nsecret: _SECRET_\nconsumer: !ruby/object:OAuth::Consumer\n  key: CONSUMER_KEY\n  secret: CONSUMER_SECRET\n  options:\n    :signature_method: HMAC-SHA1\n    :request_token_path: /oauth/request_token\n    :authorize_path: /oauth/authorize\n    :access_token_path: /oauth/access_token\n    :proxy: \n    :scheme: :header\n    :http_method: :post\n    :oauth_version: '1.0'\n    :site: https://api.twitter.com\n  http_method: :post\n  http: !ruby/object:Net::HTTP\n    address: api.twitter.com\n    port: 443\n    curr_http_version: '1.1'\n    no_keepalive_server: false\n    close_on_empty_response: false\n    socket: \n    started: false\n    open_timeout: 30\n    read_timeout: 30\n    continue_timeout: \n    debug_output: \n    use_ssl: true\n    ssl_context: !ruby/object:OpenSSL::SSL::SSLContext\n      cert: \n      key: \n      client_ca: \n      ca_file: \n      ca_path: \n      timeout: \n      verify_mode: 0\n      verify_depth: \n      verify_callback: \n      options: -2147480577\n      cert_store: \n      extra_chain_cert: \n      client_cert_cb: \n      tmp_dh_callback: \n      session_id_context: \n      session_get_cb: \n      session_new_cb: \n      session_remove_cb: \n      servername_cb: \n    enable_post_connection_check: true\n    compression: \n    sspi_enabled: false\n    ssl_version: \n    key: \n    cert: \n    ca_file: \n    ca_path: \n    cert_store: \n    ciphers: \n    verify_mode: 0\n    verify_callback: \n    verify_depth: \n    ssl_timeout: \nparams:\n  :oauth_token: _TOKEN_\n  oauth_token: _TOKEN_\n  :oauth_token_secret: _SECRET_\n  oauth_token_secret: _SECRET_\n  :user_id: USER_ID\n  user_id: USER_ID\n  :screen_name: SCREEN_NAME\n  screen_name: SCREEN_NAME\n"
    end
end