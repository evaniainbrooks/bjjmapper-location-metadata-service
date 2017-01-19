require_relative 'mongo_document'

class GooglePlacesSpot
  include MongoDocument
  COLLECTION_NAME = 'google_places_spots'
  SLICE_ATTRIBUTES = [
      :lat, :lng, :name, :icon, 
      :vicinity, :formatted_phone_number, 
      :international_phone_number, 
      :street, :city, :region, :postal_code, :country, 
      :rating, :url, :website, :review_summary, :price_level, 
      :opening_hours, :utc_offset, :place_id].freeze

  COLLECTION_FIELDS = [:lat, :lng, :viewport, :name, :icon, :reference, :vicinity, :types, :id, 
                 :formatted_phone_number, :international_phone_number, 
                 :address_components, :street_number, :street, :city, :region, :postal_code,
                 :country, :rating, :url, :cid, :website, :aspects, :zagat_selected,
                 :zagat_reviewed, :review_summary, :nextpagetoken, :price_level,
                 :opening_hours, :events, :utc_offset, :place_id,
                 :_id, :bjjmapper_location_id, :batch_id, :primary]
  
  attr_accessor *COLLECTION_FIELDS

  def address_components
    street_component = self.street ? "#{self.street_number} #{self.street}" if self.street
    street_component ||= self.vicinity.split(', ')[0] if self.vicinity

    {
      street: street_component, 
      city: city,
      state: region,
      country: country,
      postal_code: postal_code
    }
  end

  def as_json
    attrs = SLICE_ATTRIBUTES.inject({}) do |hash, k|
      hash[k] = self.send(k) if self.respond_to?(k)
      hash
    end
      
    attrs.merge(address_components).merge(title: self.name, place_url: url, source: 'Google')
  end
end
