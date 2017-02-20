module Responses
  class PhotosResponse
    EMPTY_HASH = {}.freeze
    DEFAULT_COUNT = 50

    def self.respond(photos, opts = EMPTY_HASH)
      count = opts[:count] || DEFAULT_COUNT

      google = (photos[:google] || []).collect do |o|
        o.as_json.merge(small_url: o.url.gsub(/w\d\d\d/, 'w100'))
      end
        .uniq{|o| o[:key]}
        .uniq{|o| o[:url]}
      
      facebook = (photos[:facebook] || []).group_by do |o| 
        [o.photo_id, o.is_cover_photo, o.is_profile_photo].join
      end.values.collect do |o|
        by_width = o.sort_by(&:width)
        by_width.last.as_json.merge(small_url: by_width.first.source)
      end

      yelp = photos[:yelp].collect {|o| o.as_json.merge(small_url: o.url) }.uniq {|o| o[:url] } if photos[:yelp]

      [yelp, google, facebook].compact.flatten.take(count.to_i)
    end
  end
end
