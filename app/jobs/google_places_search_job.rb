require 'resque'
require 'mongo'
require 'google_places'
require_relative '../../config'
require_relative '../models/google_places_spot'
require_relative '../models/google_places_review'
require_relative '../models/google_places_photo'
require_relative '../../lib/circle_distance'
require_relative './google_fetch_and_associate_job'

module GooglePlacesSearchJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  DISTANCE_THRESHOLD_MI = 0.4 # miles
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    spots = find_best_spots(model)
    if spots.nil? || spots.count == 0
      puts "Couldn't find anything"
      return
    end

    spots.first.tap do |spot|
      puts "Fetching detailed information for #{spot.place_id}"
      if Math.circle_distance(spot.lat, spot.lng, model['lat'], model['lng']) < DISTANCE_THRESHOLD_MI
        puts "Storing primary spot #{spot.place_id}"
        Resque.enqueue(GoogleFetchAndAssociateJob, {
          place_id: spot.place_id,
          bjjmapper_location_id: bjjmapper_location_id
        })
      end
    end

    spots.drop(1).each do |spot|
      puts "Storing secondary spot #{spot.place_id}"
      build_spot(spot, bjjmapper_location_id, batch_id).tap do |spot|
        spot.primary = false
        spot.upsert(@connection, place_id: spot.place_id)
      end
    end
  end

  private

  def self.find_best_spots(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']
    bjjmapper_location_id = model['id']

    puts "Searching for spots"
    spots = @places_client.spots(lat, lng, name: title)
    puts "Got response #{spots.count} spots for location #{bjjmapper_location_id} (using title)"
    if spots.nil?
      spots = @places_client.spots(lat, lng, types: ['gym', 'health'])
      puts "Got response #{spots.count} spots for location #{bjjmapper_location_id} (using type: gym, health)"
      if spots.count > 1
        puts "WARNING: Found more than one (#{spots.count}) spot, choosing closest"
        spots.sort_by! do |spot|
          distance = Math.circle_distance(lat, lng, spot.lat, spot.lng)
        end
      end
    end

    return nil unless spots.count > 0
    spots
  end

  def self.build_photo(response, location_id, place_id)
    GooglePlacesPhoto.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
      o.large_url = response.fetch_url(LARGE_IMAGE_WIDTH)
      o.url = response.fetch_url(IMAGE_WIDTH)
    end
  end

  def self.build_spot(response, location_id, batch_id)
    GooglePlacesSpot.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.batch_id = batch_id
    end
  end

  def self.build_review(response, location_id, place_id)
    GooglePlacesReview.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
    end
  end
end
