require 'resque'
require 'mongo'
require './config'
require './app/models/spot'
require './app/models/review'
require './app/models/photo'

module FacebookGraphSearchJob
  @places_client = GooglePlaces::Client.new(GOOGLE_PLACES_API_KEY)
  @queue = QUEUE_NAME
  @connection = Mongo::MongoClient.new(DATABASE_HOST, DATABASE_PORT).db(DATABASE_APP_DB)

  def self.perform(model)

  end
end
