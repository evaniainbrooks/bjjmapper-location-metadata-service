module Responses
  class ReviewsResponse
    def self.respond(listing_reviews)
      listing_reviews.keys.inject([]) do |arr, src|
        reviews = listing_reviews[src].map{|o|o.as_json} unless listing_reviews[src].nil?
        arr.concat(reviews || [])
      end.uniq{|o| [o[:key], o[:author_name], o[:text]]}
    end
  end
end
