require_relative 'mongo_document'

class YelpBusiness
  include MongoDocument
  COLLECTION_NAME = 'yelp_businesses'
  COLLECTION_FIELDS = [:is_claimed, :rating, :mobile_url, :rating_img_url, 
    :review_count, :name, :rating_img_url_small, :categories, :phone, 
    :snippet_text, :image_url, :snippet_image_url, :display_phone, 
    :rating_img_url_large, :yelp_id, :is_closed,

    :address, :display_address, :city, :website,
    :state_code, :postal_code, :country_code, 
    :cross_streets, :neighborhoods, :lat, :lng,
    :address1, :address2, :address3,

  :_id, :bjjmapper_location_id, :batch_id, :primary]

  attr_accessor *COLLECTION_FIELDS

  def as_json
    {
      source: 'Yelp', lat: lat, lng: lng, title: name, icon: snippet_image_url,
      is_closed: is_closed, is_claimed: is_claimed, phone: phone, website: website,
      formatted_phone: display_phone, city: city, country: country_code, 
      postal_code: postal_code, state: state_code, street: [address1, address2, address3].compact.join(' '), yelp_id: yelp_id
    }
  end
end

