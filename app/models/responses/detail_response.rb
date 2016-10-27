module Responses
  class DetailResponse
    SLICE_ATTRIBUTES = [
      :lat, :lng, :name, :icon, 
      :vicinity, :formatted_phone_number, 
      :international_phone_number, :street_number, 
      :street, :city, :region, :postal_code, :country, 
      :rating, :url, :website, :review_summary, :price_level, 
      :opening_hours, :utc_offset, :place_id].freeze

    def self.respond(spot_models)
      attributes = spot_models.values.map do |spot_model|
        SLICE_ATTRIBUTES.inject({}) do |hash, k|
          hash[k] = spot_model.send(k) if spot_model.respond_to?(k)
          hash
        end unless spot_model.nil?
      end.compact

      if attributes.size > 1
        attributes[0].merge(attributes[1])
      else
        attributes.first
      end.to_json
    end
  end
end
