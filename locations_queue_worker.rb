require 'resque'
require 'mongo'
require './config'
require './app/jobs/google_places_search_job'
require './app/jobs/yelp_search_job'

include Mongo

WAIT_INTERVAL = 10.0
RESQUE_LOCATIONS_QUEUE = "locations"

Resque.mongo = MongoClient.new(LocationFetchService::DATABASE_HOST , LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_QUEUE_DB)

STDOUT.puts "Starting locations queue worker on #{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_QUEUE_DB}"

worker = Resque::Worker.new(RESQUE_LOCATIONS_QUEUE)
worker.verbose = worker.very_verbose = true
worker.work(WAIT_INTERVAL)

