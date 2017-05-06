require 'resque'
require 'mongo'
require 'foursquare2'
require_relative '../../config'
require_relative '../../database_client'
require_relative '../models/foursquare_venue'
require_relative '../models/foursquare_photo'

module FoursquareFetchAndAssociateJob
  @queue = LocationFetchService::QUEUE_NAME
  @foursquare = client = Foursquare2::Client.new(:client_id => ENV['FOURSQUARE_APP_ID'], :client_secret => ENV['FOURSQUARE_APP_SECRET'])
  @connection = LocationFetchService::MONGO_CONNECTION
  
  def self.perform(model)
    listing = @foursquare.venue(model['foursquare_id'], m: LocationFetchService::FOURSQUARE_FORMAT, v: LocationFetchService::FOURSQUARE_API_VERSION)
    
    if listing.nil?
      puts "Couldn't find venue #{model['foursquare_id']}"
      return
    end
    
    puts "Response was #{listing.to_json}"
    
    bjjmapper_location_id = model['bjjmapper_location_id']
    detailed_listing = FoursquareVenue.from_response(listing, 
      bjjmapper_location_id: bjjmapper_location_id, 
      primary: true
    )

    puts "Listing is #{detailed_listing.inspect}"

    lat = detailed_listing.lat
    lng = detailed_listing.lng


    listing.bestPhoto.tap do |profile_photo|
      store_photo(profile_photo, bjjmapper_location_id, lat, lng, detailed_listing.foursquare_id, true)
    end if listing.bestPhoto
    
    listing.photos.groups.each do |group|
      group.items.each do |photo_response|
        store_photo(photo_response, bjjmapper_location_id, lat, lng, detailed_listing.foursquare_id, false)
      end
    end if listing.photos
    
    detailed_listing.upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, foursquare_id: detailed_listing.foursquare_id)
  end

  def self.store_photo(photo_response, bjjmapper_location_id, lat, lng, foursquare_id, is_profile_photo)
    small_photo = FoursquarePhoto.from_response(photo_response, 
      bjjmapper_location_id: bjjmapper_location_id, 
      lat: lat,
      lng: lng,
      foursquare_id: foursquare_id,
      width: FoursquarePhoto::SMALL,
      is_profile_photo: is_profile_photo
    )
    
    large_photo = FoursquarePhoto.from_response(photo_response, 
      bjjmapper_location_id: bjjmapper_location_id, 
      lat: lat,
      lng: lng,
      foursquare_id: foursquare_id,
      width: FoursquarePhoto::LARGE,
      is_profile_photo: is_profile_photo
    )

    puts "Storing photos #{small_photo.inspect} #{large_photo.inspect}"
    small_photo.upsert(@connection, foursquare_id: foursquare_id, width: small_photo.width, suffix: small_photo.suffix)
    large_photo.upsert(@connection, foursquare_id: foursquare_id, height: large_photo.width, suffix: large_photo.suffix)
  end
end
