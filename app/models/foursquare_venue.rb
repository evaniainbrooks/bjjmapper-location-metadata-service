require_relative 'mongo_document'

class FoursquareVenue
  include MongoDocument
  
  COLLECTION_NAME = 'foursquare_venues'
  COLLECTION_FIELDS = [
    :name, :phone, :twitter, :formattedPhone,
    :address, :crossStreet, :city, :state, :postalCode,
    :country, :coordinates, :distance, :isFuzzed, :verified, 
    :checkinsCount, :usersCount, :tipCount, :url, :hours, :price, 
    :rating, :description, :createdAt, :shortUrl, :canonicalUrl, :phrases, 
    :_id, :foursquare_id, :bjjmapper_location_id, :batch_id, :primary, :created_at
  ].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(listing_response, params = {})
    FoursquareVenue.new(listing_response).tap do |o|
      o.foursquare_id = listing_response.id
      o.created_at = Time.now

      if listing_response.location
        o.coordinates = [listing_response.location.lng, listing_response.location.lat]
        o.merge_attributes!(listing_response.location)
      end
      
      if listing_response.contact
        o.merge_attributes!(listing_response.contact)
      end

      if listing_response.stats
        o.merge_attributes!(listing_response.stats)
      end
      
      o.primary = params[:primary]
      o.bjjmapper_location_id = params[:bjjmapper_location_id]
      o.batch_id = params[:batch_id]
    end
  end
  
  def address_components
    {
      street: address, 
      city: city,
      state: state,
      country: country,
      postal_code: postalCode
    }
  end
  
  def lat
    coordinates.nil? ? nil : coordinates[1]
  end

  def lng
    coordinates.nil? ? nil : coordinates[0]
  end

  def as_json
    address_components.merge(
      source: 'Foursquare', 
      foursquare_id: self.foursquare_id,
      title: self.name,
      created_at: self.createdAt,
      website: self.url,
      phone: self.phone, 
      formatted_phone: self.formattedPhone,
      twitter: self.twitter,
      url: self.canonicalUrl,
      lat: self.lat,
      lng: self.lng,
      is_claimed: self.verified || false,
      phrases: self.phrases,
      rating_count: self.tipCount,
      fan_count: self.usersCount,
      checkins: self.checkinsCount 
    )
  end
end
