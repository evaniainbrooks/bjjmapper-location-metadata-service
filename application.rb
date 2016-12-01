require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'
require 'resque'

require_relative './config'
require_relative 'app/jobs/google_places_search_job'
require_relative 'app/jobs/yelp_search_job'
require_relative 'app/jobs/google_identify_candidate_locations_job'
require_relative 'app/jobs/yelp_identify_candidate_locations_job'
require_relative 'app/jobs/yelp_fetch_and_associate_job'
require_relative 'app/jobs/google_fetch_and_associate_job'

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
  WORKERS = ['locations_queue_worker']

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

      return Responses::ReviewsResponse.respond(
        {google: @spot, yelp: @yelp_business},
        {google: @google_reviews, yelp: @yelp_reviews}
      )
    end

    get '/locations/:bjjmapper_location_id/detail' do
      combined = (params[:combined] || 0).to_i == 1 ? true : false
      return Responses::DetailResponse.respond(
        {google: @spot, yelp: @yelp_business}, 
        combined)
    end
    
    post '/locations/:bjjmapper_location_id/associate' do
      if params[:google_id]
        puts "Checking google association"
        if @spot && params[:google_id] != @spot.place_id
          puts "Updating existing listing #{@spot.place_id}"
          @spot.update(settings.app_db, {:primary => false})
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {place_id: params[:google_id]}
        new_spot = GooglePlacesSpot.find(settings.app_db, conditions)
        if !new_spot.nil?
          puts "New associated listing exists #{new_spot.place_id}"
          new_spot.update(settings.app_db, {:bjjmapper_location_id => location_id, :primary => true})
        else
          puts "New associated listing does not exist, fetching"
          Resque.enqueue(GoogleFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            place_id: params[:google_id]
          })
        end
      end
      
      if params[:yelp_id]
        puts "Checking Yelp association"
        if @yelp_business && params[:yelp_id] != @yelp_business.yelp_id
          puts "Updating existing listing #{@yelp_business.yelp_id}"
          @yelp_business.update(settings.app_db, {:primary => false})
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {yelp_id: params[:yelp_id]}
        new_spot = YelpBusiness.find(settings.app_db, conditions)
        if !new_spot.nil?
          puts "New associated listing exists #{new_spot.yelp_id}"
          new_spot.update(settings.app_db, {:bjjmapper_location_id => location_id, :primary => true})
        else
          puts "New associated listing does not exist, fetching"
          Resque.enqueue(YelpFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            yelp_id: params[:yelp_id]
          })
        end
      end

      status 202
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
        unless @location
          puts "Missing location param, halting"
          halt 400 and return false
        end
      end
    end

    #
    # Search routes
    #
    post '/search/async' do
      scope = params[:scope]

      if @location['id'].nil?
        Resque.enqueue(GoogleIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'google')
        Resque.enqueue(YelpIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'yelp')
      else
        Resque.enqueue(GooglePlacesSearchJob, @location) if scope.nil? || (scope == 'google')
        Resque.enqueue(YelpSearchJob, @location) if scope.nil? || (scope == 'yelp')
      end
      status 202
    end
  end
end
