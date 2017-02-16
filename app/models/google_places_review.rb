require_relative 'mongo_document'

class GooglePlacesReview
  include MongoDocument
  COLLECTION_NAME = 'google_places_reviews'
  COLLECTION_FIELDS = [:coordinates, :type, :author_name, :author_url, :text, :time, :rating, :_id, :place_id, :bjjmapper_location_id].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    return GooglePlacesReview.new(response).tap do |o|
      o.coordinates = [params[:lng], params[:lat]]
      o.place_id = params[:place_id]
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
    ['GoogleReview', self.place_id, self.time].join('-')
  end
  
  def as_json
    [:author_name, :author_url, :text, :time, :place_id, :rating, :key].inject({}) do |hash, k|
      hash[k] = self.send(k); hash
    end.merge(source: 'Google', lat: lat, lng: lng) 
  end
end
