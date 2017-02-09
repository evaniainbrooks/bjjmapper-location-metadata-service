require 'rubygems'
require 'sinatra'
require 'active_support/all'
require 'mongo'
require 'json/ext'
require 'resque'
require 'redis'

require_relative './config'
require_relative 'app/jobs/facebook_search_job'
require_relative 'app/jobs/google_places_search_job'
require_relative 'app/jobs/yelp_search_job'
require_relative 'app/jobs/google_identify_candidate_locations_job'
require_relative 'app/jobs/yelp_identify_candidate_locations_job'
require_relative 'app/jobs/google_fetch_and_associate_job'
require_relative 'app/jobs/yelp_fetch_and_associate_job'

require_relative 'app/jobs/random_location_refresh_job'

require_relative 'app/models/facebook_page'
require_relative 'app/models/facebook_photo'

require_relative 'app/models/google_places_review'
require_relative 'app/models/google_places_spot'
require_relative 'app/models/google_places_photo'

require_relative 'app/models/yelp_business'
require_relative 'app/models/yelp_review'
require_relative 'app/models/yelp_photo'

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

      connection = MongoClient.new(DATABASE_HOST, DATABASE_PORT)
      set :mongo_connection, connection
      set :app_db, connection.db(settings.app_database_name)

      Resque.redis = ::Redis.new(host: DATABASE_HOST, password: ENV['REDIS_PASS'])
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
      pass if 'listings' == request.path_info.split('/')[2]
      
      id = params[:bjjmapper_location_id]
      conditions = {primary: true, bjjmapper_location_id: id}

      @page = FacebookPage.find(settings.app_db, conditions)
      @spot = GooglePlacesSpot.find(settings.app_db, conditions)
      @yelp_business = YelpBusiness.find(settings.app_db, conditions)
    end

    before '/locations/*' do
      pass if 'associate' == request.path_info.split('/')[2]
      pass if 'listings' == request.path_info.split('/')[2]

      if @spot.nil? && @yelp_business.nil? && @page.nil?
        puts "No listings found"
        halt 404 and return false
      end
    end

    #
    # Locations routes
    #
    get '/locations/:bjjmapper_location_id/photos' do
      unless @spot.nil?
        google_photos_conditions = {place_id: @spot.place_id}
        @google_photos = GooglePlacesPhoto.find_all(settings.app_db, google_photos_conditions)
      end
      
      unless @page.nil?
        facebook_photos_conditions = {facebook_id: @page.facebook_id}
        @facebook_photos = FacebookPhoto.find_all(settings.app_db, facebook_photos_conditions)
      end
      
      unless @yelp_business.nil?
        yelp_photo_conditions = {yelp_id: @yelp_business.yelp_id}
        @yelp_photos = YelpPhoto.find_all(settings.app_db, yelp_photo_conditions)
      end

      photos = {google: @google_photos, facebook: @facebook_photos, yelp: @yelp_photos}
      count = params[:count]
      Responses::PhotosResponse.respond(photos, count: count)
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

    get '/locations/:bjjmapper_location_id/listings' do
      conditions = { bjjmapper_location_id: params[:bjjmapper_location_id] }
      @yelp_listings = YelpBusiness.find_all(settings.app_db, conditions)
      @google_listings = GooglePlacesSpot.find_all(settings.app_db, conditions)
      @facebook_listings = FacebookPage.find_all(settings.app_db, conditions)

      context = { combined: false }
      [].concat(@yelp_listings).concat(@google_listings).concat(@facebook_listings).flatten.compact.map do |listing|
        Responses::DetailResponse.respond(context, listing: listing)
      end.to_json
    end

    get '/locations/:bjjmapper_location_id/detail' do
      context = {
        combined: (params[:combined] || 0).to_i == 1 ? true : false,
        title: params[:title],
        address: {
          lat: params[:lat].to_f,
          lng: params[:lng].to_f,
          street: params[:street],
          city: params[:city],
          state: params[:state],
          country: params[:country],
          postal_code: params[:postal_code]
        }
      }
      return Responses::DetailResponse.respond(context,
        {google: @spot, yelp: @yelp_business, facebook: @page})
    end
    
    post '/locations/:bjjmapper_location_id/associate' do
      if params[:facebook_id]
        puts "Checking facebook association"
        if @page && params[:facebook_id] != @page.facebook_id
          puts "Updating existing listing #{@page.facebook_id}"
          @page.primary = false
          @page.save(settings.app_db)
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {facebook_id: params[:facebook_id]}
        new_page = FacebookPage.find(settings.app_db, conditions)
        if !new_page.nil?
          puts "New associated listing exists #{new_page.facebook_id}"
          new_page.bjjmapper_location_id = location_id
          new_page.primary = true
          new_page.save(settings.app_db)
        else
          puts "New associated listing does not exist, fetching"
          # FIXME: This doesn't exist
          Resque.enqueue(FacebookFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            facebook_id: params[:facebook_id]
          })
        end
      end

      if params[:google_id]
        puts "Checking google association"
        if @spot && params[:google_id] != @spot.place_id
          puts "Updating existing listing #{@spot.place_id}"
          @spot.primary = false
          @spot.save(settings.app_db)
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {place_id: params[:google_id]}
        new_spot = GooglePlacesSpot.find(settings.app_db, conditions)
        if !new_spot.nil?
          puts "New associated listing exists #{new_spot.place_id}"
          new_spot.bjjmapper_location_id = location_id
          new_spot.primary = true
          new_spot.save(settings.app_db)
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
          @yelp_business.primary = false
          @yelp_business.save(settings.app_db)
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {yelp_id: params[:yelp_id]}
        new_spot = YelpBusiness.find(settings.app_db, conditions)
        if !new_spot.nil?
          puts "New associated listing exists #{new_spot.yelp_id}"
          new_spot.bjjmapper_location_id = location_id
          new_spot.primary = true
          new_spot.save(settings.app_db)
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
      location_id = @location['id']

      if location_id.nil?
        Resque.enqueue(GoogleIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'google')
        Resque.enqueue(YelpIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'yelp')
        
        status 202
        return
      end

      conditions = {bjjmapper_location_id: location_id, primary: true}
      if scope.nil? || scope == 'google'
        listing = GooglePlacesSpot.find(settings.app_db, conditions)
        if !listing.nil?
          puts "Found google listing #{listing.inspect}, refreshing"
          Resque.enqueue(GoogleFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            place_id: listing.place_id
          })
        else
          puts "No google listing, searching"
          Resque.enqueue(GooglePlacesSearchJob, @location)
        end
      end

      if scope.nil? || scope == 'yelp'
        listing = YelpBusiness.find(settings.app_db, conditions)
        if !listing.nil?
          puts "Found yelp listing #{listing.inspect}, refreshing"
          Resque.enqueue(YelpFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            yelp_id: listing.yelp_id 
          })
        else
          puts "No yelp listing, searching"
          Resque.enqueue(YelpSearchJob, @location)
        end
      end

      # There is no FetchAndAssociate for Facebook (yet)
      Resque.enqueue(FacebookSearchJob, @location) if scope.nil? || (scope == 'facebook')
      status 202
    end

    post '/search/random' do
      scope = params[:scope]
      count = params[:count]

      Resque.enqueue(RandomLocationRefreshJob, count: count, scope: scope)
      status 202
    end
  end
end
