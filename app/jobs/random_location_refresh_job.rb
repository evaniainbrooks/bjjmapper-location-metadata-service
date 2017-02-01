require 'resque'
require 'mongo'
require 'koala'
require_relative '../../config'
require_relative '../../lib/bjjmapper'

require_relative './google_places_search_job'
require_relative './yelp_search_job'
require_relative './facebook_search_job'

module RandomLocationRefreshJob 
  @queue = LocationFetchService::QUEUE_NAME
  @bjjmapper = BJJMapper.new('localhost', 80) 

  DEFAULT_LOCATION_COUNT = 100 

  def self.perform(params)
    count = (params['count'] || DEFAULT_LOCATION_COUNT).to_i
    scope = params['scope']
    
    puts "Refreshing #{count} random locations with scope #{scope}"
    count.times do |i|
      location = @bjjmapper.random_location()
      unless location
        puts "Failed to get random location, exiting"
        return 0
      end

      location_fields = { id: location['id'], lat: location['lat'], lng: location['lng'], title: location['title'] } 
      puts "Refreshing location #{location_fields.inspect}"

      Resque.enqueue(GooglePlacesSearchJob, location_fields) if scope.nil? || scope == 'google'
      Resque.enqueue(FacebookSearchJob, location_fields) if scope.nil? || scope == 'facebook'
      Resque.enqueue(YelpSearchJob, location_fields) if scope.nil? || scope == 'yelp'
    end
  end
end
