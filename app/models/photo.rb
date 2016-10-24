require './app/models/mongo_document'

class Photo
  include MongoDocument
  COLLECTION_NAME = 'google_places_photos'
end
