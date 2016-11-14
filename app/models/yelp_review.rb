class YelpReview
  include MongoDocument
  COLLECTION_NAME = 'yelp_reviews'

  attr_accessor :excerpt, :rating, :rating_image_url,
    :rating_image_small_url, :rating_image_large_url,
    :time_created, :user_id, :user_image_url, :user_name
  attr_accessor :_id, :yelp_id, :bjjmapper_location_id, :yelp_review_id

  def as_json
    {
      author_name: self.user_name,
      author_url: "https://www.yelp.com/user_details?userid=#{self.user_id}",
      text: self.excerpt,
      rating: self.rating,
      time: self.time_created,
      yelp_id: self.yelp_id,
      yelp_review_id: self.yelp_review_id,
      source: 'Yelp'
    }
  end
end
