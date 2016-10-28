require_relative 'mongo_document'

class YelpBusiness
  include MongoDocument
  COLLECTION_NAME = 'yelp_businesses'

  attr_accessor :is_claimed, :rating, :mobile_url, :rating_img_url, 
    :review_count, :name, :rating_img_url_small, :categories, :phone, 
    :snippet_text, :image_url, :snippet_image_url, :display_phone, 
    :rating_img_url_large, :yelp_id, :is_closed

  attr_accessor :address, :display_address, :city, 
    :state_code, :postal_code, :country_code, 
    :cross_streets, :neighborhoods, :lat, :lng

  attr_accessor :_id, :bjjmapper_location_id, :batch_id, :primary
end

