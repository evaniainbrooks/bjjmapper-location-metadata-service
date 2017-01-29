require_relative 'mongo_document'

class GooglePlacesPhoto
  include MongoDocument
  COLLECTION_NAME = 'google_places_photos'
  COLLECTION_FIELDS = [:width, :height, :photo_reference, 
                       :html_attributions, :large_url, :url, 
                       :_id, :place_id, :bjjmapper_location_id, :created_at].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    return GooglePlacesPhoto.new(response).tap do |o|
      o.created_at = Time.now
      o.url = params[:url]
      o.place_id = params[:place_id]
      o.bjjmapper_location_id = params[:location_id]
    end
  end

  def key
    ['GooglePhoto', self.place_id, self.photo_reference].join('-')
  end

  def as_json
    (COLLECTION_FIELDS - [:_id, :large_url]).inject({}) do |hash, k|
      hash[k] = self.send(k)
      hash
    end.merge(key: key, source: 'Google')
  end
end
