require 'resque'
require 'mongo'
require 'google_places'
require './config'
require './app/models/spot'
require './app/models/review'

module PlacesSearchJob
  @places_client = GooglePlaces::Client.new(GOOGLE_PLACES_API_KEY)
  @queue = QUEUE_NAME
  @connection = Mongo::MongoClient.new(DATABASE_HOST, DATABASE_PORT).db(DATABASE_APP_DB)

  def self.perform(model)
    bjjmapper_location_id = model['_id']
    batch_id = Time.now

    spot_responses = @places_client.spots(model['coordinates'][1], model['coordinates'][0], :name => model['title'])
    puts "Got response #{spot_responses.count} for location #{bjjmapper_location_id}"

    spot_responses.map do |spot_response|
      puts "Fetching detailed information for #{spot_response.place_id}"
      detailed_response = @places_client.spot(spot_response.place_id)
      spot = build_spot(detailed_response, bjjmapper_location_id, batch_id)

      detailed_response.reviews.map do |review_response|
        build_review(review_response, bjjmapper_location_id, spot_response.place_id)
      end.each do |review|
        puts "Saving #{review.inspect}"
        review.save(@connection)
      end

      spot
    end.each do |spot|
      puts "Saving #{spot.inspect}"
      spot.save(@connection)
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
