require 'resque'
require 'mongo'
require 'google_places'
require './config'

module PlacesSearchJob
  @places_client = GooglePlaces::Client.new(GOOGLE_PLACES_API_KEY)
  @queue = QUEUE_NAME
  @connection = Mongo::MongoClient.new(DATABASE_HOST, DATABASE_PORT).db(DATABASE_APP_DB)

  def self.perform(model)
    response = @places_client.spots(model['coordinates'][1], model['coordinates'][0]) 
    puts "Got response #{response} for location #{model['_id']}"

    batch_id = Time.now
    response.each do |spot|
      self.insert_response(model['_id'], spot, batch_id)
    end
  end

  def self.insert_response(location_id, spot, batch_id)
    create_params = {
      :location_id => location_id,
      :batch_id => batch_id,
      :response_json => spot.to_json,
      :timestamp => Time.now
    }

    @connection[GOOGLE_PLACES_RESPONSE_COLLECTION_NAME].insert(create_params)
  end
end
