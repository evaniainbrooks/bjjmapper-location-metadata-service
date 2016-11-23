require 'resque'
require 'mongo'
require 'google_places'
require_relative '../models/google_places_spot'
require_relative '../models/google_places_review'
require_relative '../models/google_places_photo'
require_relative '../../config'
require_relative '../../lib/bjjmapper'
require_relative '../../lib/circle_distance'

module GoogleIdentifyCandidateLocationsJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)

  @bjjmapper = BJJMapper.new('localhost', 80)

  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  DEFAULT_TITLE = 'brazilian'
  CATEGORY_FILTER_MARTIAL_ARTS = ['gym', 'health']
  DEFAULT_DISTANCE_MI = 25
  DISTANCE_THRESHOLD_MI = 0.4

  def self.perform(model)
    batch_id = Time.now
    puts "Searching Google for listings"
    find_academy_listings(model).each do |listing|
      listing = build_listing(listing, batch_id)
      puts "Found business #{listing.name}, #{listing.inspect}"
      
      bjjmapper_nearby_locations = @bjjmapper.map_search({sort: 'distance', distance: DISTANCE_THRESHOLD_MI, lat: listing.lat, lng: listing.lng})
      bjjmapper_nearby_locations = bjjmapper_nearby_locations ? bjjmapper_nearby_locations['locations'] : []
      puts "Founds nearby locations #{bjjmapper_nearby_locations.inspect}"

      listing.bjjmapper_location_id = create_or_associate_nearest_location(listing, bjjmapper_nearby_locations) 
      listing.upsert(@connection, place_id: listing.place_id)
    end
  end
  
  def self.create_or_associate_nearest_location(listing, nearby_locations)
    nearest = nearby_locations.first
    if !nearest.nil?
      enqueue_associate_listing_job(listing, nearest)
      nearest['id']
    else
      new_loc = create_pending_location_from_listing!(listing)
      enqueue_associate_listing_job(listing, new_loc)
      new_loc['id']
    end
  end

  def self.enqueue_associate_listing_job(listing, location)
    puts "Associating #{listing.place_id} with #{location['title']}"
    Resque.enqueue(GoogleFetchAndAssociateJob, {
      bjjmapper_location_id: location['id'],
      place_id: listing.place_id
    })
  end

  def self.create_pending_location_from_listing!(listing)
    puts "Creating candidate location #{listing.name}"
    response = @bjjmapper.create_pending_location({
      title: listing.name,
      coordinates: [listing.lng, listing.lat],
      street: listing.street,
      postal_code: listing.postal_code,
      city: listing.city,
      state: listing.region,
      country: listing.country,
      source: 'Google',
      website: listing.website,
      phone: listing.international_phone_number || listing.formatted_phone_number
    })

    puts "Created #{response['id']} location"
    response
  end
  
  def self.find_academy_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title'] || DEFAULT_TITLE

    spots = @places_client.spots(lat, lng, name: title, types: CATEGORY_FILTER_MARTIAL_ARTS)
    puts "Got response #{spots.count} spots for #{lat}, #{lng}  (using type: gym, health)"

    spots
  end

  def self.build_listing(response, batch_id)
    GooglePlacesSpot.new(response).tap do |o|
      o.batch_id = batch_id
      o.primary = true
    end
  end
end