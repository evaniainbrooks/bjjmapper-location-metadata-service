require_relative 'mongo_document'

class FacebookPage
  include MongoDocument
  COLLECTION_NAME = 'facebook_pages'
  COLLECTION_FIELDS = [:overall_star_rating, :rating_count, 
                       :phone, :link, :is_unclaimed, :is_verified, 
                       :is_permanently_closed, :fan_count, :checkins, 
                       :name, :website, :about, :description, :picture, 
                       :cover, :hours, :feed, :posts, :lat, :lng, :city, 
                       :state, :country, :street, :zip, :facebook_id, :_id, 
                       :bjjmapper_location_id, :batch_id, :primary, :created_at].freeze

  attr_accessor *COLLECTION_FIELDS
  
  def self.from_response(listing_response, params = {})
    return FacebookPage.new(listing_response).tap do |r|
      r.created_at = Time.now
      r.facebook_id = listing_response['id']
      r.merge_attributes!(listing_response['location'])
      if listing_response['location']
        r.lat = listing_response['location']['latitude']
        r.lng = listing_response['location']['longitude']
      end
      r.bjjmapper_location_id = params[:location_id]
      r.batch_id = params[:batch_id]
      r.primary = params[:primary] || false
    end
  end

  def address_components
    {
      street: street,
      city: city, 
      state: state, 
      country: country, 
      postal_code: zip
    }
  end

  def as_json
    except_fields = [:_id, :link, :is_permanently_closed, :is_unclaimed, :hours, :picture, :primary, :name]
    (COLLECTION_FIELDS - except_fields).inject({}) do |h, k|
      h[k] = self.send(k) if self.respond_to?(k)
      h
    end.merge({
      source: 'Facebook',
      title: name,
      url: link,
      is_closed: is_permanently_closed || false,
      is_claimed: !is_unclaimed || false,
      opening_hours: hours,
      image_url: picture
    }).merge(address_components)
  end
end

