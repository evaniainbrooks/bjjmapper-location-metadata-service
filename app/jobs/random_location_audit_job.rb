require 'resque'
require 'mongo'
require 'koala'
require_relative '../../config'
require_relative '../../lib/bjjmapper'

require_relative './google_search_job'
require_relative './yelp_search_job'
require_relative './facebook_search_job'

module RandomLocationAuditJob 
  @queue = LocationFetchService::QUEUE_NAME
  @bjjmapper = BJJMapper.new('localhost', 80) 

  DEFAULT_LOCATION_COUNT = 100 

  def self.perform(params)
    count = (params['count'] || DEFAULT_LOCATION_COUNT).to_i
    
    puts "Auditing #{count} random locations"
    count.times do |i|
      location = @bjjmapper.random_location()
      unless location
        puts "Failed to get random location, exiting"
        return 0
      end

      puts "Auditing location #{location.inspect}"

      params = {sort: 'distance', distance: LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI, lat: location['lat'], lng: location['lng']}
      nearby_locations = @bjjmapper.map_search(params)

      if nearby_locations.count > 1
        puts "Found possible duplicate location #{nearby_locations.first['title']}"
        @bjjmapper.notify(BJJMapper::DUPLICATE_LOCATION, 
                          "Found possible duplicate location for #{location['title']}, title is #{nearby_locations.first['title']}", 
                          location_id: location['id'], duplicate_id: nearby_locations.first['id'])
      end
    end
  end
end
