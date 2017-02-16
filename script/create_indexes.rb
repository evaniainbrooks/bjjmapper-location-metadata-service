require 'mongo'
require_relative '../config'

client = Mongo::Client.new("mongodb://#{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_APP_DB}")

client[:facebook_pages].indexes.create_one(bjjmapper_location_id: 1, facebook_id: 1)
client[:facebook_photos].indexes.create_one(width: 1, height: 1, album_id: 1, facebook_id: 1, photo_id: 1)

client[:yelp_businesses].indexes.create_one(bjjmapper_location_id: 1, yelp_id: 1)
client[:yelp_photos].indexes.create_one(bjjmapper_location_id: 1, yelp_id: 1, url: 1)
client[:yelp_reviews].indexes.create_one(yelp_id: 1, time_created: 1, user_name: 1)

client[:google_places_spots].indexes.create_one(bjjmapper_location_id: 1, place_id: 1)
client[:google_places_photos].indexes.create_one(place_id: 1, photo_reference: 1)
client[:google_places_reviews].indexes.create_one(place_id: 1, author_name: 1, time: 1)

[:facebook_pages, :facebook_photos, :yelp_businesses, :yelp_photos, :yelp_reviews, :google_places_spots, :google_places_photos, :google_places_reviews].each do |sym|
  client[sym].indexes.create_one(coordinates: "2dsphere")
end
