require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'
require 'resque'
require 'google_places'

require './config'
require './places_search_job'

require './app/models/review'
require './app/models/spot'
require './app/models/photo'

include Mongo

configure do
  set :app_file, __FILE__
  set :bind, '0.0.0.0'
  set :port, ENV['PORT']

  set :app_database_name, DATABASE_APP_DB
  set :resque_database_name, DATABASE_QUEUE_DB

  connection = MongoClient.new(DATABASE_HOST, DATABASE_PORT)
  set :mongo_connection, connection
  set :app_db, connection.db(settings.app_database_name)
  set :queue_db, connection.db(settings.resque_database_name)

  Resque.mongo = settings.queue_db
end

helpers do
  def bson_id val
    BSON::ObjectId.from_string(val)
  end
end

before { content_type :json }
before { halt 401 and return false unless params[:api_key] == APP_API_KEY }

get '/locations/:bjjmapper_location_id/photos' do
  conditions = {bjjmapper_location_id: bson_id(params[:bjjmapper_location_id])}
  photo_models = Photo.find_all(settings.mongo_db, conditions)

  halt 404 and return false if photo_models.nil?

  Responses::PhotosResponse.respond(spot_model, reviews_model)
end

get '/locations/:bjjmapper_location_id/reviews' do
  conditions = {bjjmapper_location_id: bson_id(params[:bjjmapper_location_id])}
  review_models = Review.find_all(settings.mongo_db, conditions)
  spot_model = Spot.find(settings.mongo_db, conditions)

  halt 404 and return false if spot_model.nil?

  Responses::ReviewsResponse.respond(spot_model, reviews_model)
end

get '/locations/:bjjmapper_location_id/detail' do
  conditions = {bjjmapper_location_id: bson_id(params[:bjjmapper_location_id])}
  spot_model = Spot.find(settings.mongo_db, conditions)

  halt 404 and return false if spot_model.nil?

  return Responses::DetailResponse.respond(spot_model)
end

before '/search/async' { halt 400 and return false unless params[:location] }
post '/search/async' do
  Resque.enqueue(PlacesSearchJob, JSON.parse(params[:location]))

  status 202
end

