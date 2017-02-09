require_relative 'mongo_document'

class FacebookPhoto 
  include MongoDocument
  COLLECTION_NAME = 'facebook_photos'
  COLLECTION_FIELDS = [:is_cover_photo, :is_profile_photo, :photo_id,
                       :is_silhouette, :width, :height, :source, :offset_x, :offset_y,
                       :link, :album_id, :_id, :facebook_id, :bjjmapper_location_id, :created_at].freeze

  attr_accessor *COLLECTION_FIELDS

  def self.from_response(photo_response, params = {})
    return FacebookPhoto.new(photo_response).tap do |o|
      o.created_at = Time.now
      o.source ||= photo_response['url']
      o.facebook_id = params[:facebook_id]
      o.bjjmapper_location_id = params[:bjjmapper_location_id]
      o.photo_id = params[:photo_id] || nil
      o.album_id = params[:album_id] || nil
      o.is_cover_photo = params[:is_cover_photo] || false
      o.is_profile_photo = params[:is_profile_photo] || false
    end 
  end

  def key
    ['FacebookPhoto', self.facebook_id, self.photo_id, self.width, self.height].join('-')
  end

  def as_json
    (COLLECTION_FIELDS - [:_id, :source]).inject({}) do |hash, k|
      hash[k] = self.send(k)
      hash
    end.merge(key: key, source: 'Facebook', url: self.source)
  end
end
