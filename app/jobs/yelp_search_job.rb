require 'resque'
require 'mongo'
require_relative '../../config'
require_relative '../models/yelp_business'
require_relative '../models/yelp_review'
require_relative '../../lib/yelp_fusion_client'
require_relative './google_fetch_and_associate_job'

module YelpSearchJob
  @client = YelpFusionClient.new(ENV['YELP_V3_CLIENT_ID'], ENV['YELP_V3_CLIENT_SECRET'])
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    listings = find_best_listings(model)
    if listings.nil? || listings.count == 0
      puts "Couldn't find anything"
      return
    end

    listings.first.tap do |listing|
      puts "First listing is #{listing.inspect}"
      
      Resque.enqueue(YelpFetchAndAssociateJob, {
        bjjmapper_location_id: bjjmapper_location_id,
        yelp_id: listing['id']
      })
    end

    listings.drop(1).each do |listing|
      puts "Storing secondary listing #{listing['id']}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |o|
        o.primary = false
        o.upsert(@connection, yelp_id: o.yelp_id)
      end
    end
  end

  def self.find_best_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']

    response = @client.search({ latitude: lat, longitude: lng, term: title, categories: 'martialarts' })
    puts "Search returned #{response['businesses'].count} listings"

    response['businesses']
  end

  def self.build_listing(listing_response, location_id, batch_id)
    return YelpBusiness.new(listing_response).tap do |r|
      r.name = listing_response['name']
      r.yelp_id = listing_response['id']
      r.merge_attributes!(listing_response['location'])
      if listing_response['coordinates']
        r.lat = listing_response['coordinates']['latitude']
        r.lng = listing_response['coordinates']['longitude']
      end
      r.bjjmapper_location_id = location_id
      r.batch_id = batch_id
    end
  end

  def self.build_review(review_response, location_id, yelp_id)
    return YelpReview.new(review_response).tap do |r|
      r.bjjmapper_location_id = location_id
      r.user_id = review_response['user']['id']
      r.user_image_url = review_response['user']['image_url']
      r.user_name = review_response['user']['name']
      r.yelp_id = yelp_id
    end
  end
end
