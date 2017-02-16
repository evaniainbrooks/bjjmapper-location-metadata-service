require 'resque'
require 'mongo'
require 'google_places'
require_relative '../../config'
require_relative '../models/google_spot'
require_relative '../models/google_review'
require_relative '../models/google_photo'

module GoogleFetchAndAssociateJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::Client.new("mongodb://#{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_APP_DB}")
  
  LARGE_IMAGE_WIDTH = 500
  IMAGE_WIDTH = 100

  def self.perform(model)
    listing = @places_client.spot(model['place_id'])
    bjjmapper_location_id = model['bjjmapper_location_id']
    detailed_listing = GoogleSpot.from_response(listing, 
      bjjmapper_location_id: bjjmapper_location_id, 
      primary: true
    )

    lat = detailed_listing.lat
    lng = detailed_listing.lng
    
    listing.reviews.each do |review_response|
      review = GoogleReview.from_response(review_response, 
        bjjmapper_location_id: bjjmapper_location_id, 
        lat: lat,
        lng: lng,
        place_id: detailed_listing.place_id
      )

      puts "Storing review #{review.inspect}"
      review.upsert(@connection, place_id: detailed_listing.place_id, author_name: review.author_name, time: review.time)
    end
    
    listing.photos.each do |photo_response|
      photo = GooglePhoto.from_response(photo_response, 
        bjjmapper_location_id: bjjmapper_location_id, 
        lat: lat,
        lng: lng,
        place_id: detailed_listing.place_id, 
        url: photo_response.fetch_url(LARGE_IMAGE_WIDTH)
      )

      puts "Storing photo #{photo.inspect}"
      photo.upsert(@connection, place_id: detailed_listing.place_id, photo_reference: photo.photo_reference)
    end
    
    puts "Storing listing #{detailed_listing.inspect}"
    detailed_listing.upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, place_id: detailed_listing.place_id)
  end
end
