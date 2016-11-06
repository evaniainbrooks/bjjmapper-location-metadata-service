require 'resque'
require 'mongo'
require 'yelp'
require_relative '../../config'
require_relative '../models/yelp_business'

module IdentifyCandidateLocationsJob
  @client = Yelp::Client.new({
    consumer_key: LocationFetchService::YELP_API_KEY[:consumer_key],
    consumer_secret: LocationFetchService::YELP_API_KEY[:consumer_secret],
    token: LocationFetchService::YELP_API_KEY[:token],
    token_secret: LocationFetchService::YELP_API_KEY[:token_secret]
  })
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  PAGE_LIMIT = 20
  TOTAL_LIMIT = 200

  def self.perform(model)
    batch_id = Time.now

    find_academy_listings(model).each do |listing|
      o = build_listing(listing, batch_id)
      puts "Found business #{o.name}"
      o.save(@connection)
    end
  end

  def self.find_academy_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title'] || 'brazilian'

    businesses = []
    loop do
      response = @client.search_by_coordinates({ latitude: lat, longitude: lng }, { offset: businesses.size, limit: PAGE_LIMIT, term: title, category_filter: 'martialarts' })
      puts "Search returned #{response.businesses.count} listings"
      businesses.concat(response.businesses) if response.businesses

      break if response.businesses.count < PAGE_LIMIT || businesses.count >= TOTAL_LIMIT
    
      sleep(2)
    end
    puts "Found a total of #{businesses.count} listings"

    businesses
  end

  def self.build_listing(listing_response, batch_id)
    return YelpBusiness.new(listing_response).tap do |r|
      r.yelp_id = listing_response.id
      r.merge_attributes!(listing_response.location)
      if listing_response.location && listing_response.location.coordinate
        r.lat = listing_response.location.coordinate.latitude
        r.lng = listing_response.location.coordinate.longitude
      end
      r.batch_id = batch_id
    end
  end
end