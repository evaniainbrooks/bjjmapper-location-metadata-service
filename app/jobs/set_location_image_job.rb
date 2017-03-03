require_relative '../../lib/avatar_service_client'

module SetLocationImageJob
  @avatar_service = AvatarServiceClient.new(LocationFetchService::AVATAR_SERVICE_HOST, LocationFetchService::AVATAR_SERVICE_PORT)
  @queue = LocationFetchService::QUEUE_NAME

  def self.perform(bjjmapper_location_id, url)
    @avatar_service.set_profile_image(bjjmapper_location_id, url)
  end
end
