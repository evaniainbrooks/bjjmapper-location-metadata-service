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

  LOCATION_DUPLICATE_DISTANCE_THRESHOLD = 0.25
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
      audit_duplicates(location)
    end
  end

  def self.audit_duplicates(location)
    params = {sort: 'distance', distance: LOCATION_DUPLICATE_DISTANCE_THRESHOLD, lat: location['lat'], lng: location['lng']}
    nearby_locations = @bjjmapper.map_search(params) || []
    nearby_locations = nearby_locations.select { |loc| loc['id'] != location['id'] }

    if nearby_locations.count > 0
      puts "Found possible duplicate location #{nearby_locations.first['title']}"
      @bjjmapper.notify(location['id'], BJJMapper::DUPLICATE_LOCATION, 
                        message: "Possible duplicate location for #{location['title']}, #{nearby_locations.first['title']}",
                        duplicate_location_id: nearby_locations.first['id'])
      puts "Created notification"
    end
  end
end
