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

include Mongo

configure do
  set :app_file, __FILE__
  set :bind, '0.0.0.0'
  set :port, ENV['PORT']

  set :resque_database_name, DATABASE_QUEUE_DB
  set :database_name, DATABASE_APP_DB

  connection = MongoClient.new(DATABASE_HOST, DATABASE_PORT)
  set :mongo_connection, connection
  set :mongo_db, connection.db(settings.database_name)
  set :queue_db, connection.db(settings.resque_database_name)

  Resque.mongo = settings.queue_db
end

helpers do
  # a helper method to turn a string ID
  # representation into a BSON::ObjectId
  def object_id val
    BSON::ObjectId.from_string(val)
  end

  def document_by_id id, collection
    id = object_id(id) if String === id
    settings.mongo_db[collection].find_one(:_id => id)
  end
end

before do
  halt 401 and return false unless params[:api_key] == API_KEY
end

before do
  [:location_id].each do |arg|
    unless params[arg]
      STDERR.puts "Missing #{arg}, returning 400"
      halt 400 and return false
    end
  end
end

get '/places/reviews' do
  content_type :json

  conditions = {:bjjmapper_location_id => object_id(params[:location_id])}
  review_models = Review.find_all(settings.mongo_db, conditions)
  spot_model = Spot.find(settings.mongo_db, conditions)

  reviews = review_models.map do |model|
    [:author_name, :author_url, :text, :time, :place_id].inject({}) do |hash, k|
      hash[k] = model.send(k); hash
    end
  end unless review_models.nil?

  return {
    rating: spot_model.rating,
    review_summary: spot_model.review_summary,
    reviews: reviews
  }.to_json
end

post '/places/search/async' do
  content_type :json

  model = document_by_id(params[:location_id], 'locations')
  halt 404 if model.nil?

  Resque.enqueue(PlacesSearchJob, model)

  status 202
end

