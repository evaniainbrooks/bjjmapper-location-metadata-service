module Responses
  class PhotosResponse
    def self.respond(spots, photos)
      google = (photos[:google] || []).collect do |o|
        o.as_json.merge(small_url: o.url.gsub(/w\d\d\d/, 'w100'))
      end.uniq{|o| o[:key]}
      
      facebook = (photos[:facebook] || []).group_by do |o| 
        [o.photo_id, o.is_cover_photo, o.is_profile_photo].join
      end.values.collect do |o|
        by_width = o.sort_by(&:width)
        by_width.last.as_json.merge(small_url: by_width.first.source)
      end

      [google, facebook].compact.flatten.to_json
    end
  end
end
