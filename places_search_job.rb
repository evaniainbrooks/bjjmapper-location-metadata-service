require 'resque'
require 'mongo'
require 'google_places'
require './config'
require './app/models/spot'
require './app/models/review'
require './app/models/photo'

module PlacesSearchJob
  @places_client = GooglePlaces::Client.new(GOOGLE_PLACES_API_KEY)
  @queue = QUEUE_NAME
  @connection = Mongo::MongoClient.new(DATABASE_HOST, DATABASE_PORT).db(DATABASE_APP_DB)

  def self.perform(model)
    bjjmapper_location_id = model['_id']
    batch_id = Time.now

    spot_response = find_best_spot(model)
    puts "Fetching detailed information for #{spot_response.place_id}"
    detailed_response = @places_client.spot(spot_response.place_id)
    spot = build_spot(detailed_response, bjjmapper_location_id, batch_id)

    detailed_response.reviews.each do |review_response|
      review = build_review(review_response, bjjmapper_location_id, spot_response.place_id)
      review.save(@connection)
    end

    detailed_response.photos.each do |photo_response|
      photo = build_photo(photo_response, bjjmapper_location_id, spot_response.place_id)
      photo.save(@connection)
    end

    spot.save(@connection)
  end

  private

  def self.find_best_spot(model)
    lat = model['coordinates'][1]
    lng = model['coordinates'][0]
    title = model['title']

    spot_responses = @places_client.spots(lat, lng, name: title)
    puts "Got response #{spot_responses.count} spots for location #{bjjmapper_location_id} (using title)"
    if spot_responses.blank?
      spot_responses ||= @places_client.spots(lat, lng, types: ['gym', 'health'])
      puts "Got response #{spot_responses.count} spots for location #{bjjmapper_location_id} (using type: gym, health)"
    end

    if spot_responses.count > 1
      puts "WARNING: Found more than one (#{spot_responses.count}) spot, choosing closest"
      sorted = spot_responses.sort_by do |spot|
        distance = circle_distance(lat, lng, spot.lat, spot.lng)
      end

      spot_responses.drop(1).each do |discarded_spot|
        puts "Discarding #{discarded_spot.name}"
      end

      sorted.first
    else
      spot_responses.first
    end
  end

  def self.circle_distance(lat0, lng0, lat1, lng1)
    r = 3963.0
    return r * Math.acos(Math.sin(lat0) * Math.sin(lat1) + Math.cos(lat0) * Math.cos(lat1) * Math.cos(lng1 - lng0))
  end

  def self.build_photo(response, location_id, place_id)
    Photo.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.batch_id = batch_id
    end
  end

  def self.build_spot(response, location_id, batch_id)
    Spot.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.batch_id = batch_id
    end
  end

  def self.build_review(response, location_id, place_id)
    Review.new(response).tap do |o|
      o.bjjmapper_location_id = location_id
      o.place_id = place_id
    end
  end
end
