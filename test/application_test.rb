ENV['RACK_ENV'] = 'test'

require './application'
require './config'
require 'test/unit'
require 'rack/test'
require 'mocha/test_unit'
require 'mocha/parameter_matchers'

class LocationFetchServiceTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Mocha::ParameterMatchers

  def app
    Sinatra::Application
  end

  def nubjjparos
    "54b3bc57b3e83fa6410006ba"
  end

  def test_it_returns_401_with_no_apikey
    post '/places/search'
    assert_equal 401, last_response.status
  end

  def test_it_returns_400_with_no_location_id
    post "/places/search?api_key=#{API_KEY}"
    assert_equal 400, last_response.status
  end

  def test_it_returns_404_when_model_not_found
    post "/places/search?api_key=#{API_KEY}&location_id=#{nubjjparos.reverse}"
    assert_equal 404, last_response.status
  end

  def test_it_enqueues_a_places_search_job_and_returns_202
    Resque.expects(:enqueue).with(PlacesSearchJob, anything)

    post "/places/search?api_key=#{API_KEY}&location_id=#{nubjjparos}"
    assert_equal 202, last_response.status
  end
end
