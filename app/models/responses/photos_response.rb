module Responses
  class PhotosResponse
    def self.respond(spots, photos)
      google = (photos[:google] || []).collect(&:as_json).uniq{|o| o[:key]}
      
      facebook = (photos[:facebook] || []).group_by do |o| 
        [o.photo_id, o.is_cover_photo, o.is_profile_photo].join
      end.values.collect do |o|
        o.sort_by(&:width).first.as_json
      end

      [google, facebook].compact.flatten.to_json
    end
  end
end
