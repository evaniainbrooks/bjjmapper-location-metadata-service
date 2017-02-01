require_relative 'mongo_document'

class YelpBusiness
  include MongoDocument
  COLLECTION_NAME = 'yelp_businesses'
  COLLECTION_FIELDS = [:is_claimed, :rating, :mobile_url, :rating_img_url, 
    :review_count, :name, :rating_img_url_small, :categories, :phone, 
    :snippet_text, :image_url, :snippet_image_url, :display_phone, 
    :rating_img_url_large, :yelp_id, :is_closed,
    :address, :display_address, :city, :website,
    :zip_code, :state, :state_code, 
    :postal_code, :country_code, :country,
    :cross_streets, :neighborhoods, :lat, :lng,
    :address1, :address2, :address3, :_id, :bjjmapper_location_id, 
    :batch_id, :primary, :created_at].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    YelpBusiness.new(response).tap do |o|
      o.created_at = Time.now
      o.primary = params[:primary]
      o.bjjmapper_location_id = params[:location_id]
      o.yelp_id = response['id']
      o.merge_attributes!(response['location'])
      if response['coordinates']
        o.lat = response['coordinates']['latitude']
        o.lng = response['coordinates']['longitude']
      end
    end
  end

  def address_components
    format_street = !address.nil? ? address.join(' ') : [address1, address2, address3].compact.join(' ')
    {
      street: format_street,
      city: city, 
      state: state || state_code, 
      country: country || country_code, 
      postal_code: zip_code || postal_code
    }
  end

  def as_json
    {
      source: 'Yelp', 
      url: "http://yelp.com/biz/#{yelp_id}",
      yelp_id: yelp_id,
      lat: lat, lng: lng, 
      title: name, 
      image_url: image_url,
      icon: snippet_image_url,
      is_closed: is_closed, 
      is_claimed: is_claimed, 
      phone: phone, 
      website: website,
      formatted_phone: display_phone
    }.merge(address_components)
  end
end

