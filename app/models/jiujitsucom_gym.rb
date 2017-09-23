require_relative 'mongo_document'

class JiujitsucomGym
  include MongoDocument
  
  COLLECTION_NAME = 'jiujitsucom_gyms'
  COLLECTION_FIELDS = [
    :title, :phone, :website, :url, :street, :coordinates,
    :city, :state, :postal_code, :country, :lat, :lng,  
    :_id, :jiujitsucom_id, :bjjmapper_location_id, :batch_id, :primary, :created_at
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

  def self.gen_remote_id txt
    Digest::MD5.hexdigest(txt)
  end

  def as_json
    address_components.merge(
      source: 'Jiujitsucom', 
      jiujitsucom_id: self.jiujitsucom_id,
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
