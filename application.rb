require 'rubygems'
require 'sinatra'
require 'active_support/all'
require 'mongo'
require 'json/ext'
require 'resque'
require 'redis'

require_relative './config'
require_relative 'app/jobs/facebook_search_job'
require_relative 'app/jobs/google_search_job'
require_relative 'app/jobs/yelp_search_job'
require_relative 'app/jobs/google_identify_candidate_locations_job'
require_relative 'app/jobs/yelp_identify_candidate_locations_job'
require_relative 'app/jobs/google_fetch_and_associate_job'
require_relative 'app/jobs/yelp_fetch_and_associate_job'

require_relative 'app/jobs/random_location_refresh_job'
require_relative 'app/jobs/random_location_audit_job'

require_relative 'app/models/facebook_page'
require_relative 'app/models/facebook_photo'

require_relative 'app/models/google_review'
require_relative 'app/models/google_spot'
require_relative 'app/models/google_photo'

require_relative 'app/models/yelp_business'
require_relative 'app/models/yelp_review'
require_relative 'app/models/yelp_photo'

require_relative 'app/models/responses/location_reviews_response'
require_relative 'app/models/responses/reviews_response'
require_relative 'app/models/responses/photos_response'
require_relative 'app/models/responses/detail_response'

include Mongo

module LocationFetchService
  WORKERS = ['locations_queue_worker']

  class Application < Sinatra::Application
    @mongo_connection = LocationFetchService::MONGO_CONNECTION

    configure do
      set :app_file, __FILE__
      set :bind, '0.0.0.0'
      set :port, ENV['PORT']

      set :app_database_name, LocationFetchService::DATABASE_APP_DB
      set :app_db, @mongo_connection

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
    before '/locations/:bjjmapper_location_id/?*' do
      puts "PATH INFO #{request.path_info.split('/')[-1]}"
      
      pass if 'listings' == request.path_info.split('/')[-1]
      
      scope = params[:scope]
      id = params[:bjjmapper_location_id]
      conditions = {primary: true, bjjmapper_location_id: id}

      @facebook_listing = FacebookPage.find(settings.app_db, conditions) if scope.nil? || scope == 'facebook'
      @google_listing = GoogleSpot.find(settings.app_db, conditions) if scope.nil? || scope == 'google'
      @yelp_listing = YelpBusiness.find(settings.app_db, conditions) if scope.nil? || scope == 'yelp'
    end

    before '/locations/:bjjmapper_location_id/?*' do
      pass if ['associate', 'listings', 'search'].include? request.path_info.split('/')[-1]

      if @google_listing.nil? && @yelp_listing.nil? && @facebook_listing.nil?
        puts "No listings found"
        halt 404 and return false
      end
    end

    #
    # Locations routes
    #
    get '/locations/:bjjmapper_location_id' do
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
      
      listings = {google: @google_listing, yelp: @yelp_listing, facebook: @facebook_listing}
      
      return Responses::DetailResponse.respond(context, listings).to_json
    end
    
    get '/locations/:bjjmapper_location_id/photos' do
      unless @google_listing.nil?
        google_photos_conditions = {place_id: @google_listing.place_id}
        @google_photos = GooglePhoto.find_all(settings.app_db, google_photos_conditions)
      end
      
      unless @facebook_listing.nil?
        facebook_photos_conditions = {facebook_id: @facebook_listing.facebook_id}
        @facebook_photos = FacebookPhoto.find_all(settings.app_db, facebook_photos_conditions)
      end
      
      unless @yelp_listing.nil?
        yelp_photo_conditions = {yelp_id: @yelp_listing.yelp_id}
        @yelp_photos = YelpPhoto.find_all(settings.app_db, yelp_photo_conditions)
      end

      photos = {google: @google_photos, facebook: @facebook_photos, yelp: @yelp_photos}
      count = params[:count]
      Responses::PhotosResponse.respond(photos, count: count).to_json
    end

    get '/locations/:bjjmapper_location_id/reviews' do
      unless @google_listing.nil?
        google_review_conditions = {place_id: @google_listing.place_id}
        @google_reviews = GoogleReview.find_all(settings.app_db, google_review_conditions)
      end

      unless @yelp_listing.nil?
        yelp_review_conditions = {yelp_id: @yelp_listing.yelp_id}
        @yelp_reviews = YelpReview.find_all(settings.app_db, yelp_review_conditions)
      end

      return Responses::LocationReviewsResponse.respond(
        {google: @google_listing, yelp: @yelp_listing},
        {google: @google_reviews, yelp: @yelp_reviews}
      ).to_json
    end

    get '/locations/:bjjmapper_location_id/listings' do
      conditions = { bjjmapper_location_id: params[:bjjmapper_location_id] }
      scope = params[:scope]

      @listings = []
      @listings.concat YelpBusiness.find_all(settings.app_db, conditions) if scope.nil? || scope == 'yelp'
      @listings.concat GoogleSpot.find_all(settings.app_db, conditions) if scope.nil? || scope == 'google'
      @listings.concat FacebookPage.find_all(settings.app_db, conditions) if scope.nil? || scope == 'facebook'

      halt 404 and return false unless @listings.count > 0

      context = {
        combined: false,
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

      @listings.flatten.compact.map do |listing|
        Responses::DetailResponse.respond(context, listing: listing)
      end.to_json
    end

    post '/locations/:bjjmapper_location_id/listings' do
      if params[:facebook_id]
        puts "Checking facebook association"
        if @facebook_listing && params[:facebook_id] != @facebook_listing.facebook_id
          puts "Updating existing listing #{@facebook_listing.facebook_id}"
          @facebook_listing.primary = false
          @facebook_listing.save(settings.app_db)
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
        if @google_listing && params[:google_id] != @google_listing.place_id
          puts "Updating existing listing #{@google_listing.place_id}"
          @google_listing.primary = false
          @google_listing.save(settings.app_db)
        end
        
        location_id = params[:bjjmapper_location_id]
        conditions = {place_id: params[:google_id]}
        new_spot = GoogleSpot.find(settings.app_db, conditions)
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
        if @yelp_listing && params[:yelp_id] != @yelp_listing.yelp_id
          puts "Updating existing listing #{@yelp_listing.yelp_id}"
          @yelp_listing.primary = false
          @yelp_listing.save(settings.app_db)
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
    before '/locations/:bjjmapper_location_id/search' do
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

    post '/locations/:bjjmapper_location_id/search' do
      scope = params[:scope]
      location_id = params[:bjjmapper_location_id]
      conditions = {bjjmapper_location_id: location_id, primary: true}
      if scope.nil? || scope == 'google'
        listing = GoogleSpot.find(settings.app_db, conditions)
        if !listing.nil?
          puts "Found google listing #{listing.inspect}, refreshing"
          Resque.enqueue(GoogleFetchAndAssociateJob, {
            bjjmapper_location_id: location_id,
            place_id: listing.place_id
          })
        else
          puts "No google listing, searching"
          Resque.enqueue(GoogleSearchJob, @location)
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

    #
    # Global routes
    #
    get '/photos' do
      distance = params.fetch(:distance, 25).to_i
      lat = params.fetch(:lat, nil).to_f
      lng = params.fetch(:lng, nil).to_f
      count = params.fetch(:count, 100).to_i

      conditions = { 'coordinates' => { '$geoWithin' => { '$centerSphere' => [[lng, lat], distance] }}}
      sort = [:created_at, -1]
      @google_photos = GooglePhoto.find_all(settings.app_db, conditions, sort: sort, limit: count)
      @facebook_photos = FacebookPhoto.find_all(settings.app_db, conditions, sort: sort, limit: count)
      @yelp_photos = YelpPhoto.find_all(settings.app_db, conditions, sort: sort, limit: count) 

      photos = {google: @google_photos, facebook: @facebook_photos, yelp: @yelp_photos}
      Responses::PhotosResponse.respond(photos, count: count).to_json
    end
    
    get '/reviews' do
      distance = params.fetch(:distance, 25).to_i
      lat = params.fetch(:lat, nil).to_f
      lng = params.fetch(:lng, nil).to_f
      count = params.fetch(:count, 100).to_i

      conditions = { 'coordinates' => { '$geoWithin' => { '$centerSphere' => [[lng, lat], distance] }}}
      sort = [:created_at, -1]
      @google_reviews = GoogleReview.find_all(settings.app_db, conditions, sort: sort, limit: count)
      @yelp_reviews = YelpReview.find_all(settings.app_db, conditions, sort: sort, limit: count)
      
      return Responses::ReviewsResponse.respond(
        {yelp: @yelp_reviews, google: @google_reviews},
        count: count
      ).to_json
    end

    post '/search' do
      scope = params[:scope]
      Resque.enqueue(GoogleIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'google')
      Resque.enqueue(YelpIdentifyCandidateLocationsJob, @location) if scope.nil? || (scope == 'yelp')
      
      status 202
    end

    post '/refresh' do
      scope = params[:scope]
      count = params[:count]

      Resque.enqueue(RandomLocationAuditJob, count: count)
      Resque.enqueue(RandomLocationRefreshJob, count: count, scope: scope)
      status 202
    end
  end
end
