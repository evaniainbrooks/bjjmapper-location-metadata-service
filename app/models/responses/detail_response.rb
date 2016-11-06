module Responses
  class DetailResponse
    def self.respond(spot_models, combined = false)
      #events = events_for_opening_hours(google.opening_hours) if google.opening_hours
-     attributes = spot_models.values.map do |spot_model|
-       spot_model.as_json unless spot_model.nil?
-     end.compact

      if combined
        if attributes.size > 1
          attributes[0].merge(attributes[1]).tap do |o|
            o[:source] = 'Multiple'
          end
        elsei
          attributes.first
        end.to_json
      else
        attributes.to_json
      end
    end
  end

  def self.open_now?(events)

  end

  def self.events_for_opening_hours(opening_hours)
    # use timezone

    events = opening_hours['peroids'].map do |peroid|
      start = peroid['open']
      ending = peroid['close']
      now = Time.now.beginning_of_week
      day = day_of_week(start['day'])
      Event.new.tap do |e|
        e.event_type = Event::EVENT_TYPE_OPENING_HOURS
        e.starting = now + day + hours(start['time'])
        e.ending = now + day + hours(ending['time'])
        e.event_recurrence = Event::RECURRENCE_WEEKLY
        e.weekly_recurrence_days = [day]
        e.title = "Opening Hours"
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

