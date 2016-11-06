require 'resque'
require 'mongo'
require 'google_places'
require_relative '../../config'
require_relative '../models/google_places_spot'
require_relative '../models/google_places_review'
require_relative '../models/google_places_photo'

module GoogleFetchAndAssociateJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)
  
  DISTANCE_THRESHOLD = 2 # miles
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    bjjmapper_location_id = model[:bjjmapper_location_id]
    listing = @client.business(model[:yelp_id])
    detailed_listing = build_listing(listing.business, bjjmapper_location_id)
    detailed_listing.business.reviews.each do |review_response|
      review = build_review(review_response, bjjmapper_location_id, listing.id)
      puts "Storing review #{review.inspect}"
      review.save(@connection)
    end
    puts "Storing listing #{detailed_listing.inspect}"
    detailed_listing.save(@connection)
  end

  def self.build_photo(response, location_id, place_id)
    GooglePlacesPhoto.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
      o.large_url = response.fetch_url(LARGE_IMAGE_WIDTH)
      o.url = response.fetch_url(IMAGE_WIDTH)
    end
  end

  def self.build_spot(response, location_id)
    GooglePlacesSpot.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
    end
  end

  def self.build_review(response, location_id, place_id)
    GooglePlacesReview.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
    end
  end
end
