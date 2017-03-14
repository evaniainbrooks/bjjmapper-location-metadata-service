require 'mongo'
require_relative './config'

module LocationFetchService
  MONGO_CONNECTION = Mongo::Client.new("mongodb://#{LocationFetchService::DATABASE_HOST}:#{LocationFetchService::DATABASE_PORT}/#{LocationFetchService::DATABASE_APP_DB}")
end
