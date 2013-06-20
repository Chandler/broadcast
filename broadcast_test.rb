require './broadcast'
require 'test/unit'
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class BroadcastTest < Test::Unit::TestCase
  include Rack::Test::Methods

  #overrides for testing
  @@config        = Psych.load_file('test_config.yml')
  @@twilio_config = @@config['twilio']
  @@members       = @@config['members']
  @@store         = Moneta.new(:File, :dir => 'test_moneta')
  @@client        = Twilio::REST::Client.new @@twilio_config['account_sid'], @@twilio_config['auth_token']

  puts @@config.inspect

  def app
    Sinatra::Application
  end

  def test_bad_request
    post '/incoming', params={:bad_key => "abc"}
    assert_equal 404, last_response.status
  end

  def test_unknown_sender
    @@store.clear()
    post '/incoming', params={:From => 333334234, :Body => "I'm a random creeper"}
    assert_equal 404, last_response.status
    assert_equal PERMISSION_ERROR, last_response.body
  end

  def test_known_sender
    @@store.clear()
    expected_num_friends = @@members.length - 1
    expected_response = "Great success, your message was delivered to #{expected_num_friends} friends"
    post '/incoming', params={:From => 12089912446, :Body => "I'm in the club"}
    assert_equal 200, last_response.status
    assert_equal expected_response, last_response.body
  end

  def test_over_message_limit
    @@store.clear()
    sender_number = 12239912789
    sender_name = @@members[12239912789]
    
    #most recent message was just now, should fail
    @@store[sender_name] = Time.now.to_i
    post '/incoming', params={:From => sender_number, :Body => "I'm in the club"}
    assert_equal 404, last_response.status
    assert_equal RATE_LIMIT_ERROR, last_response.body
    
    #time between now and recent message is 100 seconds longer than the rate limit
    @@store[sender_name] = Time.now.to_i - @@config['rate_limit'] - 100
    post '/incoming', params={:From => sender_number, :Body => "I'm in the club"}
    assert_equal 200, last_response.status
    
    
    #time between now and recent message is 100 seconds inside than the rate limit
    @@store[sender_name] = Time.now.to_i - @@config['rate_limit'] + 100
    post '/incoming', params={:From => sender_number, :Body => "I'm in the club"}
    assert_equal 404, last_response.status
    assert_equal RATE_LIMIT_ERROR, last_response.body
  end

  @@store.clear()
end