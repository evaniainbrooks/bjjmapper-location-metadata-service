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
  
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    bjjmapper_location_id = model['bjjmapper_location_id']
    listing = @places_client.spot(model['place_id'])
    detailed_listing = build_listing(listing, bjjmapper_location_id)
    detailed_listing.reviews.each do |review_response|
      review = build_review(review_response, bjjmapper_location_id, listing.id)
      puts "Storing review #{review.inspect}"
      review.upsert(@connection, place_id: detailed_listing.place_id, author_name: review.author_name, time: review.time)
    end
    puts "Storing listing #{detailed_listing.inspect}"
    detailed_listing.upsert(@connection, place_id: detailed_listing.place_id)
  end

  def self.build_photo(response, location_id, place_id)
    GooglePlacesPhoto.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
      o.large_url = response.fetch_url(LARGE_IMAGE_WIDTH)
      o.url = response.fetch_url(IMAGE_WIDTH)
    end
  end

  def self.build_listing(response, location_id)
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