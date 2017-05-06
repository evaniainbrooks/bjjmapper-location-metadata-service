require 'resque'
require 'mongo'
require 'google_places'
require_relative '../../config'
require_relative '../../database_client'
require_relative '../../lib/circle_distance'
require_relative '../models/google_spot'
require_relative './google_fetch_and_associate_job'

module GoogleSearchJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)
  @queue = LocationFetchService::QUEUE_NAME
  @connection = LocationFetchService::MONGO_CONNECTION

  DISTANCE_THRESHOLD_MI = 0.4 # miles
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    listings = find_best_listings(model)
    if listings.nil? || listings.count == 0
      puts "Couldn't find anything"
      return
    end

    listings.first.tap do |listing|
      Resque.enqueue(GoogleFetchAndAssociateJob, {
        place_id: listing.place_id,
        bjjmapper_location_id: bjjmapper_location_id
      })
    end

    listings.drop(1).each do |listing|
      puts "Storing secondary listing #{listing.place_id}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |listing|
        listing.primary = false
        listing.upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, place_id: listing.place_id)
      end
    end
  end

  private

  def self.find_best_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']
    bjjmapper_location_id = model['id']

    puts "Searching for listings"
    listings = @places_client.spots(lat, lng, name: title, radius: 5000)
    puts "Got response #{listings.count} listings for location #{bjjmapper_location_id} (using title)"
    if listings.nil?
      listings = @places_client.listings(lat, lng, types: ['gym', 'health'])
      puts "Got response #{listings.count} listings for location #{bjjmapper_location_id} (using type: gym, health)"
    end
      
    if !listings.nil?
      listings = listings.sort_by do |listing|
        distance = Math.circle_distance(lat, lng, listing.lat, listing.lng)
        puts "Listing '#{listing.name}' is #{distance} away from the location"
        distance
      end.select do |listing|
        distance = Math.circle_distance(lat, lng, listing.lat, listing.lng)
        distance < LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI
      end
    end

    return nil if listings.nil? || listings.count == 0
    listings
  end

  def self.build_listing(response, location_id, batch_id)
    GoogleSpot.from_response(response, bjjmapper_location_id: location_id, batch_id: batch_id)
  end
end
