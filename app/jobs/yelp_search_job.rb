require 'resque'
require 'mongo'
require 'yelp'
require_relative '../../config'
require_relative '../models/yelp_business'
require_relative '../models/yelp_review'

module YelpSearchJob
  @client = Yelp::Client.new({
    consumer_key: LocationFetchService::YELP_API_KEY[:consumer_key],
    consumer_secret: LocationFetchService::YELP_API_KEY[:consumer_secret],
    token: LocationFetchService::YELP_API_KEY[:token],
    token_secret: LocationFetchService::YELP_API_KEY[:token_secret]
  })
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    listings = find_best_listings(model)
    listings.first.tap do |listing|
      puts "Fetching detailed information for #{listing.id}"
      detailed_response = @client.business(listing.id)
      detailed_listing = build_listing(detailed_response.business, bjjmapper_location_id, batch_id)

      detailed_response.business.reviews.each do |review_response|
        review = build_review(review_response, bjjmapper_location_id, listing.id)
        puts "Storing review #{review.inspect}"
        review.save(@connection)
      end

      puts "Storing primary listing #{listing.id}"
      detailed_listing.primary = true
      detailed_listing.save(@connection)
    end

    listings.drop(1).each do |listing|
      puts "Storing secondary listing #{listing.id}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |o|
        o.primary = false
        o.save(@connection)
      end
    end
  end

  def self.find_best_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']

    response = @client.search_by_coordinates({ latitude: lat, longitude: lng }, { term: title })
    puts "Search returned #{response.businesses.count} listings"

    response.businesses
  end

  def self.build_listing(listing_response, location_id, batch_id)
    return YelpBusiness.new(listing_response).tap do |r|
      r.yelp_id = listing_response.id
      r.merge_attributes!(listing_response.location)
      r.lat = listing_response.location.coordinate.latitude
      r.lng = listing_response.location.coordinate.longitude
      r.bjjmapper_location_id = location_id
      r.batch_id = batch_id
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
