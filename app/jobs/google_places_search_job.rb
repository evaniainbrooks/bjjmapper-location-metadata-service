require 'resque'
require 'mongo'
require 'google_places'
require_relative '../../config'
require_relative '../models/google_places_spot'
require_relative '../models/google_places_review'
require_relative '../models/google_places_photo'

module GooglePlacesSearchJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  DISTANCE_THRESHOLD = 2 # miles
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    bjjmapper_location_id = model['id']
    batch_id = Time.now

    spots = find_best_spots(model)
    if spots.nil?
      puts "Couldn't find anything"
      return
    end

    spots.first.tap do |spot|
      puts "Fetching detailed information for #{spot.place_id}"
      detailed_response = @places_client.spot(spot.place_id)
      spot = build_spot(detailed_response, bjjmapper_location_id, batch_id)

      detailed_response.reviews.each do |review_response|
        review = build_review(review_response, bjjmapper_location_id, spot.place_id)
        puts "Storing review #{review.inspect}"
        review.save(@connection)
      end

      detailed_response.photos.each do |photo_response|
        photo = build_photo(photo_response, bjjmapper_location_id, spot.place_id)
        puts "Storing photo #{photo.inspect}"
        photo.save(@connection)
      end

      if circle_distance(spot.lat, spot.lng, model['lat'], model['lng']) > DISTANCE_THRESHOLD
        puts "WARNING: primary spot #{spot.place_id} is more than #{DISTANCE_THRESHOLD}mi from the location"
      end

      puts "Storing primary spot #{spot.place_id}"
      spot.primary = true
      spot.save(@connection)
    end

    spots.drop(1).each do |spot|
      puts "Storing secondary spot #{spot.place_id}"
      build_spot(spot, bjjmapper_location_id, batch_id).tap do |spot|
        spot.primary = false
        spot.save(@connection)
      end
    end
  end

  private

  def self.find_best_spots(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']
    bjjmapper_location_id = model['id']

    spots = @places_client.spots(lat, lng, name: title)
    puts "Got response #{spots.count} spots for location #{bjjmapper_location_id} (using title)"
    if spots.nil?
      spots = @places_client.spots(lat, lng, types: ['gym', 'health'])
      puts "Got response #{spots.count} spots for location #{bjjmapper_location_id} (using type: gym, health)"
      if spots.count > 1
        puts "WARNING: Found more than one (#{spots.count}) spot, choosing closest"
        spots.sort_by! do |spot|
          distance = circle_distance(lat, lng, spot.lat, spot.lng)
        end
      end
    end

    return nil unless spots.count > 0
    spots
  end

  def self.circle_distance(lat0, lng0, lat1, lng1)
    r = 3963.0
    return r * Math.acos(Math.sin(lat0) * Math.sin(lat1) + Math.cos(lat0) * Math.cos(lat1) * Math.cos(lng1 - lng0))
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
