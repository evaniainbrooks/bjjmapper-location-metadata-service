require_relative '../../lib/bjjmapper_client'

module UpdateLocationFromGoogleListingJob
  @bjjmapper = BJJMapperClient.new('localhost', 80)
  @connection = Mongo::Client.new("mongodb://#{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_APP_DB}")
  @queue = LocationFetchService::QUEUE_NAME

  def self.perform(model)
    id = model['bjjmapper_location_id']
    conditions = {primary: true, bjjmapper_location_id: id}
    listing = GoogleSpot.find(@connection, conditions)
    
    @bjjmapper.update_location(id, listing.address_components.merge(coordinates: [listing.lng, listing.lat]))
  end
end
