require 'rubygems'
require 'sinatra'
require 'mongo'
require 'json/ext'
require 'resque'
require 'google_places'

require './config'
require './places_search_job'

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

post '/places/search' do
  content_type :json

  [:location_id].each do |arg|
    unless params[arg]
      STDERR.puts "Missing #{arg}, returning 400"
      halt 400
    end
  end

  model = document_by_id(params[:location_id], 'locations')
  halt 404 if model.nil?

  Resque.enqueue(PlacesSearchJob, model)

  status 202
end

