require 'levenshtein'

require_relative '../../../lib/circle_distance'

module Responses
  class DetailResponse
    def self.respond(context, spot_models)
      attributes = spot_models.values.map do |spot_model|
        unless spot_model.nil?
          h = spot_model.as_json
          h[:opening_hours] = events_for_opening_hours(spot_model.opening_hours) if spot_model.respond_to?(:opening_hours)
          h[:levenshtein_distance] = address_distance(
            context[:address].except(:lat, :lng), 
            h.slice(:street, :city, :state, :country, :postal_code)) if context[:address]
          h[:distance] = Math.circle_distance(
            context[:address][:lat], context[:address][:lng], 
            h[:lat], h[:lng]) if context[:address]
          h
        end
      end.compact

      if context[:combined]
        (attributes || []).inject({}) do |hash, attrs|
          hash.merge(attrs.delete_if{|k,v| v.nil?})
        end.merge(source: 'Multiple').to_json
      else
        attributes.to_json
      end
    end

    def self.address_distance(addr0, addr1)
      val = Levenshtein.distance(addr0.values.compact.join(', '), addr1.values.compact.join(', '))
      puts "Comparing \"#{addr0.values.compact.join(', ')}\" with \"#{addr1.values.compact.join(', ')}\" returned #{val}"
      val
    end

    def self.events_for_opening_hours(opening_hours)
      return [] if opening_hours.nil?
      
      #Time.use_zone(timezone) do
        opening_hours['periods'].map do |period|
          start = period['open']
          ending = period['close']
          now = Time.now.beginning_of_week
          day = day_of_week(start['day'])
          {
            starting: now + day.days + hours(start['time']),
            ending: now + day.days + hours(ending['time']),
            recurrence_day: day
          }
        end
      #end
    end

    def self.day_of_week(o)
      return ((o.to_i + 6) % 7)
    end

    def self.hours(o)
      hours = o[0,2].to_i.hours
      minutes = o[2,4].to_i.minutes
      hours + minutes
    end
  end
end
