require_relative 'mongo_document'

class GoogleSpot
  include MongoDocument
  COLLECTION_NAME = 'google_places_spots'
  SLICE_ATTRIBUTES = [
      :name, :icon, 
      :vicinity, :formatted_phone_number, 
      :international_phone_number, 
      :street, :city, :region, :postal_code, :country, 
      :rating, :url, :website, :review_summary, :price_level, 
      :opening_hours, :utc_offset, :place_id, :created_at].freeze

  COLLECTION_FIELDS = [:coordinates, :viewport, :name, :icon, :reference, :vicinity, 
                       :types, :id, :formatted_phone_number, :international_phone_number, :permanently_closed, 
                       :address_components, :street_number, :street, :city, :region, :postal_code,
                       :country, :rating, :url, :cid, :website, :aspects, :zagat_selected, :zagat_reviewed, 
                       :review_summary, :nextpagetoken, :price_level, :opening_hours, :events, :utc_offset, 
                       :place_id, :_id, :bjjmapper_location_id, :batch_id, :primary, :created_at].freeze
  
  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    GoogleSpot.new(response).tap do |o|
      o.place_id = response.place_id
      o.created_at = Time.now
      o.coordinates = [response.lng, response.lat]
      o.primary = params[:primary]
      o.bjjmapper_location_id = params[:bjjmapper_location_id]
      o.batch_id = params[:batch_id]
    end
  end

  def address_components
    street_component = "#{self.street_number} #{self.street}" if self.street
    street_component ||= self.vicinity.split(', ')[0] if self.vicinity

    {
      street: street_component, 
      city: city,
      state: region,
      country: country,
      postal_code: postal_code
    }
  end
  
  def lat
    coordinates.nil? ? nil : coordinates[1]
  end

  def lng
    coordinates.nil? ? nil : coordinates[0]
  end

  def as_json
    attrs = SLICE_ATTRIBUTES.inject({}) do |hash, k|
      hash[k] = self.send(k) if self.respond_to?(k)
      hash
    end
      
    attrs.merge(address_components).merge(
      source: 'Google', 
      title: self.name, 
      url: url, 
      lat: lat,
      lng: lng,
      google_id: self.place_id,
      is_closed: self.permanently_closed
    )
  end
end
