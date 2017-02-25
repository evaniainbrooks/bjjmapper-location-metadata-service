require 'resque'
require 'mongo'
require 'google_places'
require_relative '../models/google_spot'
require_relative '../models/google_review'
require_relative '../models/google_photo'
require_relative '../../config'
require_relative '../../lib/bjjmapper'
require_relative '../../lib/circle_distance'

module GoogleIdentifyCandidateLocationsJob
  @places_client = GooglePlaces::Client.new(LocationFetchService::GOOGLE_PLACES_API_KEY)

  @bjjmapper = BJJMapper.new('localhost', 80)

  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::Client.new(LocationFetchService::DATABASE_URI)

  DEFAULT_TITLE = 'brazilian'
  CATEGORY_FILTER_MARTIAL_ARTS = ['gym', 'health']
  DEFAULT_DISTANCE_MI = 25

  def self.perform(model)
    batch_id = Time.now
    puts "Searching Google for listings"
    find_academy_listings(model).each do |listing_response|
      listing = GoogleSpot.from_response(listing_response, batch_id: batch_id) 
      puts "Found business #{listing.name}, #{listing.inspect}"
      if should_filter?(listing.name.downcase)
        puts "Filtering #{listing.name} because of title"
        next
      end

      bjjmapper_nearby_locations = @bjjmapper.map_search({sort: 'distance', distance: LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI, lat: listing.lat, lng: listing.lng})
      puts "Founds nearby locations #{bjjmapper_nearby_locations.inspect}"

      listing.bjjmapper_location_id = create_or_associate_nearest_location(listing, bjjmapper_nearby_locations) 
      listing.upsert(@connection, bjjmapper_location_id: listing.bjjmapper_location_id, place_id: listing.place_id)
    end
  end
  
  def self.should_filter?(name)
    name_components = name.split.collect(&:downcase).to_set
    filtered_word = LocationFetchService::TITLE_BLACKLIST_WORDS.detect {|word| name_components.include?(word) }
    return !filtered_word.nil?
  end

  def self.should_whitelist?(name)
    name_components = name.split.collect(&:downcase).to_set
    whitelist_word = LocationFetchService::TITLE_WHITELIST_WORDS.detect {|word| name_components.include?(word) }
    return !whitelist_word.nil?
  end
  
  def self.create_or_associate_nearest_location(listing, nearby_locations)
    nearest = nearby_locations.first
    if !nearest.nil?
      enqueue_associate_listing_job(listing, nearest)
      nearest['id']
    else
      new_loc = create_location_from_listing!(listing)
      enqueue_associate_listing_job(listing, new_loc)
      new_loc['id']
    end
  end

  def self.enqueue_associate_listing_job(listing, location)
    puts "Associating #{listing} with #{location['title']}"
    Resque.enqueue(GoogleFetchAndAssociateJob, {
      bjjmapper_location_id: location['id'],
      place_id: listing.place_id
    })
  end

  def self.create_location_from_listing!(listing)
    puts "Creating candidate location #{listing.name}"
    
    o = listing.as_json
    puts o.inspect
    response = @bjjmapper.create_location({
      title: o[:title],
      coordinates: [o[:lng], o[:lat]],
      street: o[:street], 
      postal_code: o[:postal_code],
      city: o[:city],
      state: o[:state],
      country: o[:country],
      source: 'Google',
      phone: o[:phone],
      website: o[:website],
      flag_closed: o[:is_closed],
      status: should_whitelist?(o[:title]) ? BJJMapper::LOCATION_STATUS_VERIFIED : BJJMapper::LOCATION_STATUS_PENDING
    })

    puts "Created #{response['id']} location"
    response
  end
  
  def self.find_academy_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title'] || DEFAULT_TITLE

    spots = @places_client.spots(lat, lng, name: title, radius: 50000, types: CATEGORY_FILTER_MARTIAL_ARTS)
    puts "Got response #{spots.count} spots for #{lat}, #{lng}  (using type: gym, health)"

    spots
  end
end
