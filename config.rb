require 'koala'

module LocationFetchService
  DATABASE_HOST = ENV['RACK_ENV'] == 'production' ? 'services.bjjmapper.com' : 'localhost'
  DATABASE_PORT = 27017
  DATABASE_APP_DB = 'location_fetch_service' 

  QUEUE_NAME = "locations"

  GOOGLE_PLACES_API_KEY = ENV['GOOGLE_PLACES_API_KEY']
  YELP_API_KEY = {
    consumer_key: ENV['YELP_API_CONSUMER_KEY'],
    consumer_secret: ENV['YELP_API_CONSUMER_SECRET'],
    token: ENV['YELP_API_TOKEN'],
    token_secret: ENV['YELP_API_TOKEN_SECRET']
  }.freeze

  APP_API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"

  TITLE_BLACKLIST_WORDS = ['wingchun', 'chun', 'kung', 'kung-fu', 'kungfu', 'capoeira', 'karate', 'tae', 'kwondo', 'tae-kwondo', 'taekwondo', 'kwon', 'krav', 'maga', 'cultural', 'aikido', 'ai-kido', 'kido'].freeze
  TITLE_WHITELIST_WORDS = ['brazilian', 'jiu-jitsu', 'jitsu', 'mma', 'judo', 'gracie', 'bjj', 'submission', 'grappling'].freeze

  Koala.config.api_version = "v2.8"
end
