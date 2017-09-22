require_relative 'mongo_document'

class JiujitsucomGym
  include MongoDocument
  
  COLLECTION_NAME = 'jiujitsucom_gyms'
  COLLECTION_FIELDS = [
    :title, :phone, :website, :url, :street, 
    :city, :state, :postal_code, :country, :lat, :lng,  
    :_id, :remote_id, :bjjmapper_location_id, :batch_id, :primary, :created_at
  ].freeze

  attr_accessor *COLLECTION_FIELDS

  def address_components
    {
      street: street, 
      city: city,
      state: state,
      country: country,
      postal_code: postal_code
    }
  end

  def as_json
    address_components.merge(
      source: 'Jiujitsucom', 
      remote_id: self.remote_id,
      url: self.url,
      title: self.title,
      created_at: self.created_at,
      website: self.website,
      phone: self.phone, 
      url: self.url,
      lat: self.lat,
      lng: self.lng
    )
  end
end
