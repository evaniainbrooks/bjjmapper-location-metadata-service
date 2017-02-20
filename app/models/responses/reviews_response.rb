module Responses
  class ReviewsResponse
    def self.respond(listings, listing_reviews)
      reviews = build_reviews_hash(listing_reviews)
      return {
        rating: calculate_total_rating(listings, listing_reviews),
        count: reviews.count,
        reviews: reviews
      }
    end

    def self.build_reviews_hash(review_models)
      review_models.keys.inject([]) do |arr, src|
        reviews = review_models[src].map{|o|o.as_json} unless review_models[src].nil?
        arr.concat(reviews || [])
      end.uniq{|o| [o[:key], o[:author_name], o[:text]]}
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
      return nil unless spot.rating && reviews.size > 0
      
      rating = spot.rating
      rating = rating || begin
        reviews.inject(0.0) do |sum, r|
          sum = sum + r.rating.to_f
        end / reviews.count
      end if reviews.count > 0
    
      rating
    end
  end
end
