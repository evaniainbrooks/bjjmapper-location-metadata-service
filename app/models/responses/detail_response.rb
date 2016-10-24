module Responses
  class DetailResponse
    SLICE_ATTRIBUTES = [
      :lat, :lng, :name, :icon, 
      :vicinity, :formatted_phone_number, 
      :international_phone_number, :street_number, 
      :street, :city, :region, :postal_code, :country, 
      :rating, :url, :website, :review_summary, :price_level, 
      :opening_hours, :utc_offset, :place_id].freeze

    def self.respond(spot_model)
      return SLICE_ATTRIBUTES.inject({}) do |hash, k|
        hash[k] = spot_model.send(k); hash
      end.to_json
    end
  end
end
