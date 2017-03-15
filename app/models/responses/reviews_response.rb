module Responses
  class ReviewsResponse
    def self.respond(listing_reviews, params = {})
      count = params.fetch(:count, 100)
      listing_reviews.keys.inject([]) do |arr, src|
        reviews = listing_reviews[src].map{|o|o.as_json} unless listing_reviews[src].nil?
        arr.concat(reviews || [])
      end.uniq{|o| [o[:key], o[:author_name], o[:text]]}.take(count)
    end
  end
end
