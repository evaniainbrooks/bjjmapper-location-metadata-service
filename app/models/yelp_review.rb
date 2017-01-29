class YelpReview
  include MongoDocument
  COLLECTION_NAME = 'yelp_reviews'
  COLLECTION_FIELDS = [:excerpt, :rating, :rating_image_url,
    :rating_image_small_url, :rating_image_large_url, :url,
    :time_created, :user_id, :user_image_url, :user_name,
    :_id, :yelp_id, :bjjmapper_location_id, :text].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(response, params = {})
    return YelpReview.new(response).tap do |r|
      r.bjjmapper_location_id = params[:location_id]
      r.yelp_id = params[:yelp_id]
      r.user_id = response['user']['id']
      r.user_image_url = response['user']['image_url']
      r.user_name = response['user']['name']
    end
  end

  def key
    ['YelpReview', self.yelp_id, self.time].join('-')
  end

  def time
    self.time_created.is_a?(String) ? Time.parse(self.time_created).to_i : self.time_created
  end

  def as_json

    {
      author_name: self.user_name,
      author_url: (self.user_id.nil? ? self.url : "https://www.yelp.com/user_details?userid=#{self.user_id}"),
      text: self.excerpt || self.text,
      rating: self.rating,
      time: self.time, 
      yelp_id: self.yelp_id,
      source: 'Yelp',
      key: self.key
    }
  end
end
