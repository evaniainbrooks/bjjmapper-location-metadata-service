require 'dotenv'
Dotenv.load

require 'resque'
require 'mongo'
require './config'
require './app/jobs/google_places_search_job'
require './app/jobs/yelp_search_job'
require './app/jobs/google_identify_candidate_locations_job'
require './app/jobs/yelp_identify_candidate_locations_job'
require './app/jobs/google_fetch_and_associate_job'
require './app/jobs/yelp_fetch_and_associate_job'

include Mongo

module LocationFetchService
  class LocationsQueueWorker < Resque::Worker
    WAIT_INTERVAL = 10.0
    RESQUE_LOCATIONS_QUEUE = "locations"
  
    def initialize
      super(RESQUE_LOCATIONS_QUEUE)
    end

    def work
      super(WAIT_INTERVAL)
    end

    def self.run(mongo)
      STDOUT.puts "Starting locations queue worker on #{mongo.inspect}"

      Resque.mongo = mongo
      worker = LocationFetchService::LocationsQueueWorker.new
      worker.verbose = worker.very_verbose = true
      worker.work
    end
  end
end

if $0 == __FILE__
  mongo = MongoClient.new(LocationFetchService::DATABASE_HOST , LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_QUEUE_DB)
  LocationFetchService::LocationsQueueWorker.run(mongo)
end
