require 'koala'

module LocationFetchService
  DATABASE_HOST = ENV['RACK_ENV'] == 'production' ? 'services.bjjmapper.com' : 'localhost'
  DATABASE_PORT = 27017
  DATABASE_APP_DB = 'location_fetch_service' 
  DATABASE_URI = "mongodb://#{DATABASE_HOST}:#{DATABASE_PORT}/#{DATABASE_APP_DB}"

  BJJMAPPER_HOST = 'localhost'
  BJJMAPPER_PORT = 80
  BJJMAPPER_CLIENT_SETTINGS = {
    host: BJJMAPPER_HOST,
    port: BJJMAPPER_PORT,
    api_key: ENV['BJJMAPPER_API_KEY']
  }.freeze

  AVATAR_SERVICE_HOST = 'localhost'
  AVATAR_SERVICE_PORT = '80'

  QUEUE_NAME = 'locations'

  GOOGLE_PLACES_API_KEY = ENV['GOOGLE_PLACES_API_KEY']
  YELP_API_KEY = {
    consumer_key: ENV['YELP_API_CONSUMER_KEY'],
    consumer_secret: ENV['YELP_API_CONSUMER_SECRET'],
    token: ENV['YELP_API_TOKEN'],
    token_secret: ENV['YELP_API_TOKEN_SECRET']
  }.freeze

  APP_API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"

  TITLE_BLACKLIST_WORDS = [
    'ilovekickboxing',
    'bodyshaping',
    'family',
    'ata',
    'wingchun',
    'chun',
    'kung',
    'kung-fu',
    'kungfu',
    'capoeira',
    'karate',
    'tae',
    'kwondo',
    'tae-kwondo',
    'taekwondo',
    'kwon',
    'krav',
    'maga',
    'cultural',
    'aikido',
    'ai-kido',
    'kido'
  ].freeze

  TITLE_WHITELIST_WORDS = [
    'brazilian',
    'jiu-jitsu',
    'jitsu',
    'mma',
    'judo',
    'gracie',
    'bjj',
    'submission',
    'grappling'
  ].freeze

  LISTING_DISTANCE_THRESHOLD_MI = 0.4

  Koala.config.api_version = "v2.8"
end
