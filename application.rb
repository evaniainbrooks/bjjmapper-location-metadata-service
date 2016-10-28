require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'
require 'resque'

require_relative 'config'
require_relative 'app/jobs/google_places_search_job'
require_relative 'app/jobs/yelp_search_job'

require_relative 'app/models/google_places_review'
require_relative 'app/models/google_places_spot'
require_relative 'app/models/google_places_photo'

require_relative 'app/models/yelp_business'
require_relative 'app/models/yelp_review'

require_relative 'app/models/responses/reviews_response'
require_relative 'app/models/responses/photos_response'
require_relative 'app/models/responses/detail_response'

include Mongo

module LocationFetchService
  class Application < Sinatra::Application
    configure do
      set :app_file, __FILE__
      set :bind, '0.0.0.0'
      set :port, ENV['PORT']

      set :app_database_name, DATABASE_APP_DB
      set :resque_database_name, DATABASE_QUEUE_DB

      connection = MongoClient.new(DATABASE_HOST, DATABASE_PORT)
      set :mongo_connection, connection
      set :app_db, connection.db(settings.app_database_name)
      set :queue_db, connection.db(settings.resque_database_name)

      Resque.mongo = settings.queue_db
    end

    #
    # Global before
    #
    before { content_type :json }
    before { halt 401 and return false unless params[:api_key] == APP_API_KEY }

    #
    # Locations before (set location)
    #
    before '/locations/:bjjmapper_location_id/*' do
      id = params[:bjjmapper_location_id]
      conditions = {primary: true, bjjmapper_location_id: id}

      @spot = GooglePlacesSpot.find(settings.app_db, conditions)
      @yelp_business = YelpBusiness.find(settings.app_db, conditions)
    end

    before '/locations/*' do
      if @spot.nil? && @yelp_business.nil?
        puts "No listings found"
        halt 404 and return false
      end
    end

    #
    # Locations routes
    #
    get '/locations/:bjjmapper_location_id/photos' do
      photo_conditions = {place_id: @spot.place_id}
      photo_models = GooglePlacesPhoto.find_all(settings.app_db, photo_conditions)

      Responses::PhotosResponse.respond(@spot, photo_models)
    end

    get '/locations/:bjjmapper_location_id/reviews' do
      unless @spot.nil?
        google_review_conditions = {place_id: @spot.place_id}
        @google_reviews = GooglePlacesReview.find_all(settings.app_db, google_review_conditions)
      end

      unless @yelp_business.nil?
        yelp_review_conditions = {yelp_id: @yelp_business.yelp_id}
        @yelp_reviews = YelpReview.find_all(settings.app_db, yelp_review_conditions)
      end

      Responses::ReviewsResponse.respond(
        {google: @spot, yelp: @yelp_business},
        {google: @google_reviews, yelp: @yelp_reviews}
      )
    end

    get '/locations/:bjjmapper_location_id/detail' do
      return Responses::DetailResponse.respond({google: @spot, yelp: @yelp_business})
    end

    #
    # Search before
    #
    before '/search/async' do
      begin
        request.body.rewind
        body = JSON.parse(request.body.read)
        @location = body['location']
      ensure
        halt 400 and return false unless @location
      end
    end

    #
    # Search routes
    #
    post '/search/async' do
      scope = params[:scope]

      Resque.enqueue(GooglePlacesSearchJob, @location) if scope.nil? || (scope == 'google')
      Resque.enqueue(YelpSearchJob, @location) if scope.nil? || (scope == 'yelp')

      status 202
    end
  end
end
