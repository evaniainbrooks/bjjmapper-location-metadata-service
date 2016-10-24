DATABASE_HOST = ENV['RACK_ENV'] == 'production' ? 'services.bjjmapper.com' : 'localhost'
DATABASE_PORT = 27017
DATABASE_APP_DB = 'location_fetch_service' 
DATABASE_QUEUE_DB = 'resque'

QUEUE_NAME = "locations"

GOOGLE_PLACES_API_KEY = "AIzaSyAuLA-LpDpafAs7p0XH4nE8yj__Rr2oD0s"
APP_API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"
