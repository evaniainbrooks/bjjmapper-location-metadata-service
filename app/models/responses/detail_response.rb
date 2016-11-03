module Responses
  class DetailResponse
    def self.respond(spot_models)
      attributes = spot_models.values.map do |spot_model|
        spot_model.as_json unless spot_model.nil?
      end.compact

      if attributes.size > 1
        attributes[0].merge(attributes[1]).tap do |o|
          o[:source] = 'Multiple'
        end
      else
        attributes.first
      end.to_json
    end
  end
end
