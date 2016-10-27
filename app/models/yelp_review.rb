class YelpReview
  include MongoDocument
  COLLECTION_NAME = 'yelp_reviews'

  attr_accessor :excerpt, :rating, :rating_image_url,
    :rating_image_small_url, :rating_image_large_url,
    :time_created, :user_id, :user_image_url, :user_name
  attr_accessor :_id, :yelp_id, :bjjmapper_location_id
end
