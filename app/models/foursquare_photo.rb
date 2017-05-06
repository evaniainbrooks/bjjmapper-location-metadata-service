require_relative 'mongo_document'

class FoursquarePhoto
  include MongoDocument
  COLLECTION_NAME = 'foursquare_photos'
  COLLECTION_FIELDS = [:coordinates, :width, :url, :prefix, :suffix, :createdAt,
                       :_id, :foursquare_id, :bjjmapper_location_id, :created_at, :is_profile_photo].freeze

  LARGE = 500
  SMALL = 100

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    return FoursquarePhoto.new(response).tap do |o|
      o.created_at = Time.now
      o.url = params[:url]
      o.coordinates = [params[:lng], params[:lat]]
      o.foursquare_id = params[:foursquare_id]
      o.bjjmapper_location_id = params[:bjjmapper_location_id]
      o.width = params[:width]
      o.url = [response.prefix, 'width', o.width, response.suffix]
    end
  end

  def lat
    coordinates.nil? ? nil : coordinates[1]
  end

  def lng
    coordinates.nil? ? nil : coordinates[0]
  end
  
  def key
    ['FoursquarePhoto', self.foursquare_id, self.prefix, self.width].join('-')
  end

  def as_json
    {
      created_at: self.created_at,
      source: 'Foursquare',
      url: self.url,
      lat: self.lat,
      lng: self.lng,
      width: self.width,
      key: self.key,
      prefix: self.prefix,
      is_profile_photo: self.is_profile_photo 
    }
  end
end
