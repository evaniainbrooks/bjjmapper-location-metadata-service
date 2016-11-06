require 'resque'
require 'mongo'
require 'yelp'
require_relative '../../config'
require_relative '../models/yelp_business'
require_relative '../models/yelp_review'

module YelpFetchAndAssociateJob
  @client = Yelp::Client.new({
    consumer_key: LocationFetchService::YELP_API_KEY[:consumer_key],
    consumer_secret: LocationFetchService::YELP_API_KEY[:consumer_secret],
    token: LocationFetchService::YELP_API_KEY[:token],
    token_secret: LocationFetchService::YELP_API_KEY[:token_secret]
  })
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

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

  def self.build_listing(listing_response, location_id)
    return YelpBusiness.new(listing_response).tap do |r|
      r.yelp_id = listing_response.id
      r.merge_attributes!(listing_response.location)
      r.lat = listing_response.location.coordinate.latitude
      r.lng = listing_response.location.coordinate.longitude
      r.bjjmapper_location_id = location_id
      r.primary = true
    end
  end
  
  def self.build_review(review_response, location_id, yelp_id)
    return YelpReview.new(review_response).tap do |r|
      r.bjjmapper_location_id = location_id
      r.user_id = review_response.user['id']
      r.user_image_url = review_response.user['image_url']
      r.user_name = review_response.user['name']
      r.yelp_id = yelp_id
    end
  end
end
