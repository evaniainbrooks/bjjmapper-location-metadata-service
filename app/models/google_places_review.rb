require_relative 'mongo_document'

class GooglePlacesReview
  include MongoDocument
  COLLECTION_NAME = 'google_places_reviews'
  
  #<GooglePlaces::Review:0x00000000fcc470 @rating=5, @type=nil, @author_name="Nick Ryan", @author_url="https://plus.google.com/118291419032510822017", @text="Whether you are experienced grappler or a brand new student Marcelo Alonso's Academy is the perfect place to learn.", @time=1470757105>
  
  attr_accessor :type, :author_name, :author_url, :text, :time, :rating
  attr_accessor :_id, :place_id, :bjjmapper_location_id
end
