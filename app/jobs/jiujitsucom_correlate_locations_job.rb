require 'resque'
require 'mongo'
require 'nokogiri'
require 'open-uri'
require 'bjjmapper_api_client'
require 'geocoder'

require_relative '../../config'
require_relative '../../database_client'
require_relative '../models/jiujitsucom_gym'

Geocoder.configure(
  ip_lookup: :google,
  timeout: 7,
  use_https: true,
  api_key: LocationFetchService::GOOGLE_GEOCODER_API_KEY,
  cache: ::Redis.new(host: LocationFetchService::DATABASE_HOST, password: ENV['REDIS_PASS']),
  cache_prefix: 'geocoder-google'
)

module JiujitsucomCorrelateLocationsJob
  @queue = LocationFetchService::IMPORT_QUEUE_NAME
  @connection = LocationFetchService::MONGO_CONNECTION
  
  @bjjmapper = BJJMapper::ApiClient.new(LocationFetchService::BJJMAPPER_CLIENT_SETTINGS)

  SLEEPY_TIME = 5
  GYMS_URL = 'https://jiujitsu.com/gyms/'.freeze
  CREATE_VERIFIED = true
  FETCH_MAX = 10
  SKIP_CREATE = false
  SKIP_FETCH_COUNT = 0

  def self.create_or_associate_location! gymattrs, stats
    addrs = geocode_address(gymattrs[:address], stats)
    if addrs.empty?
      puts "No geocoder results"
      return
    end

    attrs = gymattrs.merge(addrs[0].deep_symbolize_keys)
    map_search_params = { rejected: 1, unverified: 1, closed: 1, sort: 'distance', distance: LocationFetchService::LISTING_DISTANCE_THRESHOLD_MI, lat: attrs[:lat], lng: attrs[:lng] }
    bjjmapper_nearby_locations = @bjjmapper.map_search(map_search_params)
    puts "Founds nearby locations #{bjjmapper_nearby_locations.inspect}"
    nearest = bjjmapper_nearby_locations.first
    if !nearest.nil?
      associate_listing! attrs, nearest, stats
    else
      puts "Creating location #{attrs}"
      response = @bjjmapper.create_location({
        title: attrs[:name],
        coordinates: [attrs[:lng], attrs[:lat]],
        street: attrs[:street], 
        postal_code: attrs[:postal_code],
        city: attrs[:city],
        state: attrs[:state],
        country: attrs[:country],
        source: 'Jiujitsucom',
        phone: attrs[:phone],
        website: attrs[:website],
        flag_closed: false,
        status: CREATE_VERIFIED ? BJJMapper::ApiClient::LOCATION_STATUS_VERIFIED : BJJMapper::ApiClient::LOCATION_STATUS_PENDING
      })
      
      stats[:created_count] += 1
      puts "Created #{response['id']} location"
      
      associate_listing! attrs, response, stats
    end
  end

  def self.perform(options = {})
    puts "Fetching #{GYMS_URL}"
    page = Nokogiri::HTML(open(GYMS_URL))

    stats = {
      error_count: 0,
      processed_count: 0,
      fetched_count: 1,
      geocoded_count: 0,
      created_count: 0,
      associated_count: 0
    }

    skip_fetch = options.fetch(:skip_fetch, SKIP_FETCH_COUNT)
    page.css('.gym-list .stated .children a').collect { |cat| cat['href'] }.drop(skip_fetch).each do |link|
      begin
        puts "Fetching #{link}"
        subpage = Nokogiri::HTML(open(link))
        stats[:fetched_count] += 1
        if stats[:fetched_count] >= options.fetch(:max, FETCH_MAX)
          puts "Reached max"
          puts stats
          exit
        end

        subpage.css('.business-name > td').each do |business|
          elems = business.children.to_a.delete_if {|x| x.text !~ /\w/}
          puts "Found #{elems.size} text nodes"
          if elems.size >= 3
            attrs = { 
              name: elems[0].text.strip,
              phone: elems[1].text.strip,
              address: elems[2].text.strip,
              website: elems.size > 3 ? elems[3].text.strip : nil,
              url: elems[0]['href']
            }

            stats[:processed_count] += 1
            JiujitsucomCorrelateLocationsJob.create_or_associate_location!(attrs, stats)
          else
            puts "Not what I expected: #{elems.collect(&:text).collect(&:strip).join('\r\n')}"
          end
        end

      rescue StandardError => e
        puts "Failed to fetch/parse link #{e.message}"
        puts e.backtrace
        stats[:error_count] += 1
      end

      puts "Finished with #{stats}"
      puts "Sleeping"
      sleep options.fetch(:sleep_time, SLEEPY_TIME)
    end
  end

  def self.geocode_address address, stats
    stats[:geocoded_count] += 1
    Geocoder.search(address).map do |r|
      {
        address: r.address,
        street: r.street_address,
        postal_code: r.postal_code,
        city: r.city,
        state: r.state,
        country: r.country
      }.merge(r.geometry['location'])
    end
  end

  def self.associate_listing! attrs, nearest, stats
    stats[:associated_count] += 1
    puts "Associating #{attrs[:name]} with #{nearest['title']}"

    JiujitsucomGym.new.tap do |gym|
      gym.title = attrs[:name]
      gym.phone = attrs[:phone]
      gym.website = attrs[:website]
      gym.street = attrs[:street]
      gym.postal_code = attrs[:postal_code]
      gym.city = attrs[:city]
      gym.state = attrs[:state]
      gym.country = attrs[:country]
      gym.lat = attrs[:lat]
      gym.lng = attrs[:lng]
      gym.coordinates = [attrs[:lng], attrs[:lat]]
      gym.url = attrs[:url]
      gym.bjjmapper_location_id = nearest['id']
      gym.created_at = Time.now
      gym.primary = true
      gym.jiujitsucom_id = JiujitsucomGym.gen_remote_id attrs[:url]
    end.upsert(@connection, bjjmapper_location_id: nearest['id'], jiujitsucom_id: JiujitsucomGym.gen_remote_id(attrs[:url]))
  end
end

