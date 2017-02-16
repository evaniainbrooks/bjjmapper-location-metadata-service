require_relative 'mongo_document'

class YelpPhoto
  include MongoDocument
  COLLECTION_NAME = 'yelp_photos'
  COLLECTION_FIELDS = [:coordinates, :url, :width, :height, :_id, :bjjmapper_location_id, :yelp_id, :created_at].freeze 

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(photo, params = {})
    return YelpPhoto.new(url: photo).tap do |o|
      o.created_at = Time.now
      o.coordinates = [params[:lng], params[:lat]]
      o.yelp_id = params[:yelp_id]
      o.bjjmapper_location_id = params[:bjjmapper_location_id]
    end
  end
  
  def lat
    coordinates.nil? ? nil : coordinates[1]
  end

  def lng
    coordinates.nil? ? nil : coordinates[0]
  end

  def key
    ['YelpPhoto', self.yelp_id, self.url.gsub(/\W/, '')].join('-')
  end

  def as_json
    {
      created_at: self.created_at,
      source: 'Yelp',
      url: self.url,
      lat: self.lat,
      lng: self.lng,
      key: key
    }
  end
end
