require_relative '../../config'
require_relative '../../database_client'
require_relative '../../lib/bjjmapper_client'

module UpdateLocationFromGoogleListingJob
  @bjjmapper = BJJMapperClient.new('localhost', 80)
  @connection = LocationFetchService::MONGO_CONNECTION
  @queue = LocationFetchService::QUEUE_NAME

  def self.perform(model)
    id = model['bjjmapper_location_id']
    conditions = {primary: true, bjjmapper_location_id: id}
    listing = GoogleSpot.find(@connection, conditions)
    
    @bjjmapper.update_location(id, listing.address_components.merge(coordinates: [listing.lng, listing.lat]))
  end
end
