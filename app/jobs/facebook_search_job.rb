require 'resque'
require 'mongo'
require 'koala'
require_relative '../../config'
require_relative '../models/facebook_page'

module FacebookSearchJob
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)
  @redis = ::Redis.new(host: LocationFetchService::DATABASE_HOST, password: ENV['REDIS_PASS'])

  REQUEST_FIELDS = %w(overall_star_rating rating_count posts videos feed phone place_type link is_unclaimed is_verified is_permanently_closed hours founded fan_count checkins displayed_message_response_time display_subtext about bio description rating id name picture cover email location timezone updated_at albums website).freeze

  def self.perform(model)
    client = Koala::Facebook::API.new(oauth_token)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    listings = find_best_listings(client, model)
    if listings.nil? || listings.count == 0
      puts "Couldn't find anything"
      return
    end

    listings.first.tap do |listing|
      puts "First listing is #{listing.inspect}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |o|
        o.primary = true 
        o.upsert(@connection, facebook_id: o.facebook_id)
      end
      
      #Resque.enqueue(FacebookFetchAndAssociateJob, {
      #  bjjmapper_location_id: bjjmapper_location_id,
      #  facebook_id: listing['id']
      #})
    end

    listings.drop(1).each do |listing|
      puts "Storing secondary listing #{listing['id']}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |o|
        o.primary = false
        o.upsert(@connection, facebook_id: o.facebook_id)
      end
    end
  end

  def self.oauth_token
    token = @redis.get('facebook-graph-oauth-token')
    if token.nil?
      oauth = Koala::Facebook::OAuth.new(ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET'])
      token = oauth.get_app_access_token
      @redis.set('facebook-graph-oauth-token', token)
      @redis.expire('facebook-graph-oauth-token', 60 * 60 * 24)
    end

    token
  end

  def self.find_best_listings(client, model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']

    response = client.search(title, { 
      fields: REQUEST_FIELDS.join(','),
      center: [lat, lng].join(','),
      type: 'place',
      distance: 10000,
    })

    puts "Search returned #{response.count} listings"

    response
  end

  def self.build_listing(listing_response, location_id, batch_id)
    return FacebookPage.new(listing_response).tap do |r|
      r.name = listing_response['name']
      r.facebook_id = listing_response['id']
      r.merge_attributes!(listing_response['location'])
      if listing_response['location']
        r.lat = listing_response['location']['latitude']
        r.lng = listing_response['location']['longitude']
      end
      r.bjjmapper_location_id = location_id
      r.batch_id = batch_id
    end
  end
end
