require_relative '../../config'
require_relative '../../database_client'
require 'bjjmapper_api_client'

module UpdateLocationFromGoogleListingJob
  @bjjmapper = BJJMapper::ApiClient.new(LocationFetchService::BJJMAPPER_CLIENT_SETTINGS)
  @connection = LocationFetchService::MONGO_CONNECTION
  @queue = LocationFetchService::QUEUE_NAME

  def self.perform(model)
    id = model['bjjmapper_location_id']
    conditions = {primary: true, bjjmapper_location_id: id}
    listing = GoogleSpot.find(@connection, conditions)
    
    @bjjmapper.update_location(id, listing.address_components.merge(coordinates: [listing.lng, listing.lat]))
  end
end
