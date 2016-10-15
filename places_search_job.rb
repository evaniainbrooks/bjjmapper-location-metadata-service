require 'resque'
require 'mongo'
require 'google_places'
require './config'

module PlacesSearchJob
  @places_client = GooglePlaces::Client.new(GOOGLE_PLACES_API_KEY)
  @queue = QUEUE_NAME
  @connection = Mongo::MongoClient.new(DATABASE_HOST, DATABASE_PORT).db(DATABASE_APP_DB)

  SPOT_FIELDS = [:lat, :lng, :viewport, :name, :icon, :reference, :vicinity, :types, :id,
                 :formatted_phone_number, :international_phone_number, :formatted_address,
                 :address_components, :street_number, :street, :city, :region, :postal_code,
                 :country, :rating, :url, :cid, :website, :reviews, :aspects, :zagat_selected,
                 :zagat_reviewed, :review_summary, :nextpagetoken, :price_level,
                 :opening_hours, :events, :utc_offset, :place_id].freeze

  MORE_FIELDS = [:photos].freeze

  def self.perform(model)
    response = @places_client.spots(model['coordinates'][1], model['coordinates'][0], :name => model['title'])
    puts "Got response #{response} for location #{model['_id']}"

    batch_id = Time.now
    response.each do |spot|
      self.insert_response(model['_id'], spot, batch_id)
    end
  end

  def self.insert_response(location_id, spot, batch_id)
    create_params = {
      :location_id => location_id,
      :batch_id => batch_id,
      :timestamp => Time.now,
      :response => SPOT_FIELDS.inject({}) { |hash, field| hash[field] = spot[field]; hash }
    }

    @connection[GOOGLE_PLACES_RESPONSE_COLLECTION_NAME].insert(create_params)
  end
end
