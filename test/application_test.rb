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
    post '/search/async'
    assert_equal 401, last_response.status
  end

  def test_detail_returns_404_when_spot_not_found
    post "/locations/#{nubjjparos.reverse}/detail?api_key=#{APP_API_KEY}"
    assert_equal 404, last_response.status
  end

  def test_detail_returns_200_when_spot_found
    post "/locations/#{nubjjparos}/detail?api_key=#{APP_API_KEY}"
    assert_equal 200, last_response.status
  end

  def test_reviews_returns_404_when_spot_not_found
    post "/locations/#{nubjjparos.reverse}/reviews?api_key=#{APP_API_KEY}"
    assert_equal 404, last_response.status
  end

  def test_reviews_returns_200_when_spot_found
    post "/locations/#{nubjjparos}/reviews?api_key=#{APP_API_KEY}"
    assert_equal 200, last_response.status
  end

  def test_search_returns_400_with_no_location_body
    params = {}
    post "/search/async?api_key=#{APP_API_KEY}", params
    assert_equal 400, last_response.status
  end

  def test_search_enqueues_search_jobs_and_returns_202
    Resque.expects(:enqueue).with(GooglePlacesSearchJob, anything)
    Resque.expects(:enqueue).with(YelpSearchJob, anything)

    params = { location: { id: nubjjparos, title: 'NUBJJ Paros', lat: 80.0, lng: 80.0 } }

    post "/search/async?api_key=#{APP_API_KEY}", params.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert_equal 202, last_response.status
  end

  def test_search_with_scope_enqueues_search_job_and_returns_202
    Resque.expects(:enqueue).with(YelpSearchJob, anything)

    params = { location: { id: nubjjparos, title: 'NUBJJ Paros', lat: 80.0, lng: 80.0 } }

    post "/search/async?api_key=#{APP_API_KEY}&scope=yelp", params.to_json, { 'CONTENT_TYPE' => 'application/json' }
    assert_equal 202, last_response.status
  end
end
