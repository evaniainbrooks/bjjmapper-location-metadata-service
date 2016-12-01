require 'resque'
require 'mongo'
require 'yelp'
require_relative '../../config'
require_relative '../models/yelp_business'
require_relative '../../lib/bjjmapper'
require_relative '../../lib/circle_distance'

module YelpIdentifyCandidateLocationsJob
  @client = Yelp::Client.new({
    consumer_key: LocationFetchService::YELP_API_KEY[:consumer_key],
    consumer_secret: LocationFetchService::YELP_API_KEY[:consumer_secret],
    token: LocationFetchService::YELP_API_KEY[:token],
    token_secret: LocationFetchService::YELP_API_KEY[:token_secret]
  })

  @bjjmapper = BJJMapper.new('localhost', 80)

  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::MongoClient.new(LocationFetchService::DATABASE_HOST, LocationFetchService::DATABASE_PORT).db(LocationFetchService::DATABASE_APP_DB)

  PAGE_LIMIT = 20
  TOTAL_LIMIT = 200
  DEFAULT_TITLE = 'brazilian'
  CATEGORY_FILTER_MARTIAL_ARTS = 'martialarts'
  FILTER_WORDS = ['capoeira', 'karate', 'taekwondo', 'cultural', 'aikido'].freeze
  DEFAULT_DISTANCE_MI = 25
  DISTANCE_THRESHOLD_MI = 0.4

  def self.perform(model)
    batch_id = Time.now
    puts "Searching Yelp for listings"
    find_academy_listings(model) do |block|
      block.each do |listing|
        listing = build_listing(listing, batch_id)
        puts "Found business #{listing.name}, #{listing.inspect}"
       
        if should_filter?(listing.name)
          puts "Filtering #{listing.name} because of title"
          next
        end

        bjjmapper_nearby_locations = @bjjmapper.map_search({sort: 'distance', distance: DISTANCE_THRESHOLD_MI, lat: listing.lat, lng: listing.lng})
        puts "Founds nearby locations #{bjjmapper_nearby_locations.inspect}"

        listing.bjjmapper_location_id = create_or_associate_nearest_location(listing, bjjmapper_nearby_locations) 
        listing.upsert(@connection, yelp_id: listing.yelp_id)
      end
    end
  end

  def self.should_filter?(name)
    name_components = name.split.collect(&:downcase).to_set
    filtered_word = FILTER_WORDS.detect {|word| name_components.include?(word) }
    return !filtered_word.nil?
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
    puts "Associating #{listing.yelp_id} with #{location['title']}"
    Resque.enqueue(YelpFetchAndAssociateJob, {
      bjjmapper_location_id: location['id'],
      yelp_id: listing.yelp_id
    })
  end

  def self.create_pending_location_from_listing!(listing)
    puts "Creating candidate location #{listing.name}"
    response = @bjjmapper.create_pending_location({
      title: listing.name,
      coordinates: [listing.lng, listing.lat],
      street: (listing.address || []).join(', '),
      postal_code: listing.postal_code,
      city: listing.city,
      state: listing.state_code,
      country: listing.country_code,
      source: 'Yelp',
      phone: listing.phone || listing.display_phone,
      flag_closed: listing.is_closed
    })

    puts "Created #{response['id']} location"
    response
  end

  def self.find_academy_listings(model)
    lat = model['lat']
    lng = model['lng']
    title = model['title'] || DEFAULT_TITLE

    businesses_count = 0
    loop do
      response = @client.search_by_coordinates({ distance: DEFAULT_DISTANCE_MI, latitude: lat, longitude: lng }, 
                                               { offset: businesses_count, limit: PAGE_LIMIT, 
                                                 term: title, category_filter: CATEGORY_FILTER_MARTIAL_ARTS })
      
      puts "Search returned #{(response.businesses || []).count} listings"
      break unless response.businesses && response.businesses.count > 0

      yield response.businesses
      businesses_count = businesses_count + response.businesses.count

      break if response.businesses.count < PAGE_LIMIT || businesses_count >= TOTAL_LIMIT
    
      sleep(2)
    end
  end

  def self.build_listing(listing_response, batch_id)
    return YelpBusiness.new(listing_response).tap do |r|
      r.name = listing_response.name
      r.yelp_id = listing_response.id
      r.merge_attributes!(listing_response.location)
      if listing_response.location && listing_response.location.coordinate
        r.lat = listing_response.location.coordinate.latitude
        r.lng = listing_response.location.coordinate.longitude
      end
      r.batch_id = batch_id
      r.primary = true
    end
  end
end