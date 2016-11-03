require_relative 'mongo_document'

class GooglePlacesReview
  include MongoDocument
  COLLECTION_NAME = 'google_places_reviews'
  
  attr_accessor :type, :author_name, :author_url, :text, :time, :rating
  attr_accessor :_id, :place_id, :bjjmapper_location_id

  def as_json
    [:author_name, :author_url, :text, :time, :place_id, :rating].inject({}) do |hash, k|
      hash[k] = self.send(k); hash
    end.merge(source: 'google')
  end
end
