module Responses
  class ReviewsResponse
    def self.respond(listings, reviews)
      return {
        rating: calculate_total_rating(listings, reviews),
        reviews: build_reviews_hash(reviews)
      }.to_json
    end

    def self.build_reviews_hash(review_models)
      google_reviews = review_models[:google].map do |model|
        [:author_name, :author_url, :text, :time, :place_id, :rating].inject({}) do |hash, k|
          hash[k] = model.send(k); hash
        end.merge(source: 'Google')
      end unless review_models[:google].nil?
      
      yelp_reviews = review_models[:yelp].map do |model|
        {
          author_name: model.user_name,
          author_url: "https://www.yelp.com/user_details?userid=#{model.user_id}",
          text: model.excerpt,
          rating: model.rating,
          time: model.time_created,
          yelp_id: model.yelp_id,
          source: 'Yelp'
        }
      end unless review_models[:yelp].nil?

      [].concat(google_reviews || []).concat(yelp_reviews || []).compact
    end

    def self.calculate_total_rating(spot_models, review_models)
      google = spot_models[:google]
      yelp = spot_models[:yelp]

      google = calculate_rating(google, review_models[:google]) unless google.nil?
      yelp = calculate_rating(yelp, review_models[:yelp]) unless yelp.nil?
    
      return 0.0 if google.nil? && yelp.nil?

      components = [google, yelp].compact
      components.inject(&:+) / components.size
    end

    def self.calculate_rating(spot, reviews)
      rating = spot.rating
      rating = rating || begin
        reviews.inject(0.0) do |sum, r|
          sum = sum + r[:rating].to_f
        end / reviews.count
      end if reviews.count > 0
    
      rating
    end
  end
end
