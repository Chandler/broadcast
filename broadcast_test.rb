require 'my_app'
require 'test/unit'
require 'rack/test'

set :environment, :test

class BroadcastTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_bad_request
    get '/incoming'
    assert_equal 'Hello World!', last_response.body
  end
end