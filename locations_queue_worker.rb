require 'resque'
require 'mongo'
require './config'
require './google_places_search_job'
require './facebook_graph_search_job'

include Mongo

WAIT_INTERVAL = 30.0
RESQUE_LOCATIONS_QUEUE = "locations"

Resque.mongo = MongoClient.new(DATABASE_HOST , DATABASE_PORT).db(DATABASE_QUEUE_DB)

STDOUT.puts "Starting locations queue worker on #{DATABASE_HOST}:#{DATABASE_PORT}/#{DATABASE_QUEUE_DB}"

worker = Resque::Worker.new(RESQUE_LOCATIONS_QUEUE)
worker.verbose = worker.very_verbose = true
worker.work(WAIT_INTERVAL)

