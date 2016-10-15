DATABASE_HOST = ENV['RACK_ENV'] == 'production' ? 'services.bjjmapper.com' : 'localhost'
DATABASE_PORT = 27017
DATABASE_APP_DB = ENV['RACK_ENV'] == 'production' ? 'rollfindr_prod' : 'rollfindr'
DATABASE_QUEUE_DB = 'resque'

QUEUE_NAME = "locations"

GOOGLE_PLACES_RESPONSE_COLLECTION_NAME = "place_responses"
GOOGLE_PLACES_API_KEY = "AIzaSyAuLA-LpDpafAs7p0XH4nE8yj__Rr2oD0s"

API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"
