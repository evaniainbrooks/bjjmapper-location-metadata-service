require 'foursquare2'
require 'resque'
require 'mongo'
require_relative '../../config'
require_relative '../../database_client'
require_relative '../../lib/circle_distance'
require_relative '../models/foursquare_venue'
require_relative './foursquare_fetch_and_associate_job'

module FoursquareSearchJob
  @queue = LocationFetchService::QUEUE_NAME
  @foursquare = client = Foursquare2::Client.new(:client_id => ENV['FOURSQUARE_APP_ID'], :client_secret => ENV['FOURSQUARE_APP_SECRET'])
  @connection = LocationFetchService::MONGO_CONNECTION
  
  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    listings = find_best_listings(model)
    if listings.nil? || listings.count == 0
      puts "Couldn't find anything"
      return
    end

    build_listing(listings.first, bjjmapper_location_id, batch_id).tap do |listing|
      puts "Primary listing is #{listing.inspect}"
      
      Resque.enqueue(FoursquareFetchAndAssociateJob, {
        foursquare_id: listing.foursquare_id,
        bjjmapper_location_id: listing.bjjmapper_location_id
      })
    end

    listings.drop(1).each do |listing|
      foursquare_id = listing.id
      puts "Storing secondary listing #{foursquare_id}"
      build_listing(listing, bjjmapper_location_id, batch_id).tap do |o|
        o.primary = false
        o.upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, foursquare_id: foursquare_id)
      end
    end
  end

  def self.find_best_listings(model)
    ll = [model['lat'], model['lng']].join(', ')
    title = model['title']
    bjjmapper_location_id = model['id']

    params = {
      ll: ll, 
      query: title,
      #radius: LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI * 1609.34, # Meters per mile 
      intent: LocationFetchService::FOURSQUARE_INTENT, 
      m: LocationFetchService::FOURSQUARE_FORMAT, 
      v: LocationFetchService::FOURSQUARE_API_VERSION
    }
    puts "Searching for listings with #{params.inspect}"
    response = @foursquare.search_venues(params)
    puts "Got response #{response.venues.count} listings for location #{bjjmapper_location_id} (using title)"

    return nil if response.venues.nil? || response.venues.count == 0
    
    response.venues.sort_by do |listing|
      distance = Math.circle_distance(model['lat'], model['lng'], listing.location.lat, listing.location.lng)
      puts "Listing '#{listing.name}' is #{distance} away from the location"
      distance
    end.select do |listing|
      distance = Math.circle_distance(model['lat'], model['lng'], listing.location.lat, listing.location.lng)
      distance < LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI
    end.tap do |listings|
      puts "#{listings.count} listings remain after filtering"
    end
  end
  
  def self.build_listing(response, location_id, batch_id)
    FoursquareVenue.from_response(response, bjjmapper_location_id: location_id, batch_id: batch_id)
  end
end
