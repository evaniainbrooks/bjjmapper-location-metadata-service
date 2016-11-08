require_relative 'mongo_document'

class GooglePlacesSpot
  include MongoDocument
  COLLECTION_NAME = 'google_places_spots'
  SLICE_ATTRIBUTES = [
      :lat, :lng, :name, :icon, 
      :vicinity, :formatted_phone_number, 
      :international_phone_number, :street_number, 
      :street, :city, :region, :postal_code, :country, 
      :rating, :url, :website, :review_summary, :price_level, 
      :opening_hours, :utc_offset, :place_id].freeze

  attr_accessor  :lat, :lng, :viewport, :name, :icon, :reference, :vicinity, :types, :id,
                 :address_components, :street_number, :street, :city, :region, :postal_code,
                 :country, :rating, :url, :cid, :website, :aspects, :zagat_selected,
                 :zagat_reviewed, :review_summary, :nextpagetoken, :price_level,
                 :opening_hours, :events, :utc_offset, :place_id

  attr_accessor  :_id, :bjjmapper_location_id, :batch_id, :primary

  def as_json
    SLICE_ATTRIBUTES.inject({}) do |hash, k|
      hash[k] = self.send(k) if self.respond_to?(k)
      hash
    end.merge(title: self.name)
  end
end
