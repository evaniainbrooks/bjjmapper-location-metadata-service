module Responses
  class DetailResponse
    def self.respond(spot_models, combined = false)
      attributes = spot_models.values.map do |spot_model|
        spot_model.as_json unless spot_model.nil?
      end.compact

      if combined
        (attributes || []).inject({}) do |hash, attrs|
          hash.merge(attrs.delete_if{|k,v| v.nil?})
        end.merge(source: 'Multiple').to_json
      else
        attributes.to_json
      end
    end

    def self.events_for_opening_hours(opening_hours)
      Time.use_zone(timezone) do
        events = opening_hours['peroids'].map do |peroid|
          start = peroid['open']
          ending = peroid['close']
          now = Time.now.beginning_of_week
          day = day_of_week(start['day'])
          {
            starting: now + day + hours(start['time']),
            ending: now + day + hours(ending['time']),
            recurrence_day: day
          }
        end
      end
    end

    def self.day_of_week(o)
      return ((o.to_i + 6) % 7).days
    end

    def self.hours(o)
      return Time.parse("#{o[0,2]}:#{o[2,4]}").hours
    end
  end
end
