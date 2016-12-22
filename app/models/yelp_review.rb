class YelpReview
  include MongoDocument
  COLLECTION_NAME = 'yelp_reviews'
  COLLECTION_FIELDS = [:excerpt, :rating, :rating_image_url,
    :rating_image_small_url, :rating_image_large_url, :url,
    :time_created, :user_id, :user_image_url, :user_name,
    :_id, :yelp_id, :bjjmapper_location_id, :text]

  attr_accessor *COLLECTION_FIELDS

  def as_json
    created = self.time_created.is_a?(String) ? Time.parse(self.time_created).to_i : self.time_created

    {
      author_name: self.user_name,
      author_url: (self.user_id.nil? ? self.url : "https://www.yelp.com/user_details?userid=#{self.user_id}"),
      text: self.excerpt || self.text,
      rating: self.rating,
      time: created,
      yelp_id: self.yelp_id,
      source: 'Yelp',
      key: "Yelp#{created}"
    }
  end
end
