require_relative 'mongo_document'

class GooglePlacesPhoto
  include MongoDocument
  COLLECTION_NAME = 'google_places_photos'

  attr_accessor :width, :height, :photo_reference,
    :html_attributions, :large_url, :url

  attr_accessor :_id, :place_id, :bjjmapper_location_id
end
