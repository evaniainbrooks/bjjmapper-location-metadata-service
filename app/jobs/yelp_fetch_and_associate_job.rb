require 'resque'
require 'mongo'
require_relative '../../config'
require_relative '../models/yelp_business'
require_relative '../models/yelp_review'
require_relative '../models/yelp_photo'
require_relative '../../lib/yelp_fusion_client'

module YelpFetchAndAssociateJob
  @client = YelpFusionClient.new(ENV['YELP_V3_CLIENT_ID'], ENV['YELP_V3_CLIENT_SECRET'])
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::Client.new("mongodb://#{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_APP_DB}")

  def self.perform(model)
    bjjmapper_location_id = model['bjjmapper_location_id']
    listing = @client.business(URI::encode(model['yelp_id']))
    
    if listing['error']
      puts "Got error response #{listing['error'].inspect}, exiting"
      return 0
    end

    detailed_listing = build_listing(listing, bjjmapper_location_id)
   
    if listing['photos']
      puts "Storing photos #{listing['photos'].inspect}"
      listing['photos'].each do |url| 
        params = { bjjmapper_location_id: bjjmapper_location_id, yelp_id: listing['id'] }
        YelpPhoto.from_response(url, params).upsert(@connection, params.merge(url: url))
      end
    end

    reviews_response = @client.reviews(URI::encode(listing['id']))
    puts "reviews response is #{reviews_response.inspect}"
    reviews_response['reviews'].each do |review_response|
      review = build_review(review_response, bjjmapper_location_id, listing['id'])
      puts "Storing review #{review.inspect}"
      review.upsert(@connection, yelp_id: detailed_listing.yelp_id, time_created: review.time_created, user_name: review.user_name)
    end if reviews_response && reviews_response['reviews']

    puts "Storing listing #{detailed_listing.inspect}"
    detailed_listing.upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, yelp_id: detailed_listing.yelp_id)
  end

  def self.build_listing(listing_response, location_id)
    YelpBusiness.from_response(listing_response, bjjmapper_location_id: location_id, primary: true)
  end
  
  def self.build_review(review_response, location_id, yelp_id)
    YelpReview.from_response(review_response, bjjmapper_location_id: location_id, yelp_id: yelp_id)
  end
end
