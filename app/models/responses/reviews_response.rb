module Responses
  class ReviewsResponse
    def self.respond(spot_model, review_models)
      return {
        rating: calculate_rating(spot_model, review_models),
        review_summary: spot_model.review_summary,
        reviews: build_reviews_hash(review_models)
      }.to_json
    end

    def self.build_reviews_hash(review_models)
      reviews = review_models.map do |model|
        [:author_name, :author_url, :text, :time, :place_id, :rating].inject({}) do |hash, k|
          hash[k] = model.send(k); hash
        end
      end unless review_models.nil?
      
      reviews
    end

    def self.calculate_rating(spot_model, review_models)
      rating = spot_model.rating
      rating ||= begin
        reviews.inject(0.0) do |sum, r|
          sum = sum + r[:rating].to_f
        end / reviews.count
      end if reviews.count > 0
    
      rating
    end
  end
end
