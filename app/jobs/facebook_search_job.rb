require 'resque'
require 'mongo'
require 'koala'
require_relative '../../config'
require_relative '../models/facebook_page'
require_relative '../models/facebook_photo'

require_relative '../../lib/avatar_service_client'

module FacebookSearchJob
  @queue = LocationFetchService::QUEUE_NAME
  @connection = Mongo::Client.new(LocationFetchService::DATABASE_URI)
  @redis = ::Redis.new(host: LocationFetchService::DATABASE_HOST, password: ENV['REDIS_PASS'])

  PICTURE_WIDTH = 1000

  PHOTO_FIELDS = %w(id source name link images width height).freeze

  MAX_PHOTOS_PER_ALBUM = 20
  MAX_ALBUMS = 5

  STORE_PROFILE_PICTURE = true

  REQUEST_FIELDS = %W(photos{#{PHOTO_FIELDS.join(',')}} overall_star_rating rating_count posts videos feed phone place_type link is_unclaimed is_verified is_permanently_closed hours founded fan_count checkins displayed_message_response_time display_subtext about bio description rating id name picture.width(#{PICTURE_WIDTH}) cover email location timezone updated_at albums{id,count,cover_photo,link,place,is_default,photos{#{PHOTO_FIELDS.join(',')}}} website).freeze
      
  OAUTH_TOKEN_CACHE_KEY = 'facebook-graph-oauth-token'
  OAUTH_TOKEN_CACHE_EXPIRE = 60 * 60 * 24

  def self.perform(model)
    client = Koala::Facebook::API.new(oauth_token)
    bjjmapper_location_id = model['id']
    lat = model['lat']
    lng = model['lng']
    batch_id = Time.now

    listings = find_best_listings(client, model)
    if listings.nil? || listings.count == 0
      puts "Couldn't find anything"
      return
    end

    listings.first.tap do |listing|
      puts "First listing is #{listing.inspect}"
      facebook_id = listing['id']
      FacebookPage.from_response(listing, {
        facebook_id: facebook_id, 
        bjjmapper_location_id: bjjmapper_location_id, 
        batch_id: batch_id,
        primary: true
      }).upsert(@connection, bjjmapper_location_id: bjjmapper_location_id, facebook_id: facebook_id)

      puts "Storing profile photo"
      if (listing['picture'])
        picture_response = listing['picture']['data']
        puts "Processing image #{picture_response.inspect}"
        
        model = FacebookPhoto.from_response(picture_response, {
          facebook_id: facebook_id, 
          lat: lat, 
          lng: lng,
          bjjmapper_location_id: bjjmapper_location_id, 
          is_profile_photo: true
        })
          
        model.upsert(@connection, {
          is_profile_photo: true, 
          facebook_id: facebook_id
        })

        if STORE_PROFILE_PICTURE && !model.is_silhouette
          avatar_service.set_profile_image(bjjmapper_location_id, model.source)
        end
      end

      puts "Storing cover photo"
      if (listing['cover'])
        picture_response = listing['cover']
        puts "Processing image #{picture_response.inspect}"
        
        FacebookPhoto.from_response(picture_response, { 
          facebook_id: facebook_id, 
          lat: lat,
          lng: lng,
          bjjmapper_location_id: bjjmapper_location_id, 
          is_cover_photo: true
        }).tap do |photo|
          photo.offset_x = picture_response['offset_x']
          photo.offset_y = picture_response['offset_y']
          photo.upsert(@connection, {is_cover_photo: true, facebook_id: facebook_id})
        end
      end

      puts "Storing photos"
      process_photos(listing['photos']['data'] || [], {
        facebook_id: facebook_id, 
        lat: lat, 
        lng: lng,
        bjjmapper_location_id: bjjmapper_location_id
      }) if listing['photos']

      puts "Storing album photos"
      (listing['albums']['data'] || []).take(MAX_ALBUMS).each do |album|
        album_id = album['id']
        puts "Processing album #{album_id}"
        process_photos(album['photos']['data'] || [], {
          facebook_id: facebook_id, 
          lat: lat, 
          lng: lng,
          bjjmapper_location_id: bjjmapper_location_id, 
          album_id: album_id
        }) if album['photos']
      end if listing['albums']
    end

    listings.drop(1).each do |listing|
      puts "Storing secondary listing #{listing['name']}"
      FacebookPage.from_response(listing, location_id: bjjmapper_location_id, batch_id: batch_id).tap do |o|
        o.primary = false
        o.upsert(@connection, facebook_id: o.facebook_id)
      end
    end
  end

  def self.avatar_service
    @_avatar_service ||= AvatarServiceClient.new(LocationFetchService::AVATAR_SERVICE_HOST, LocationFetchService::AVATAR_SERVICE_PORT)
    @_avatar_service
  end

  def self.oauth_token
    token = @redis.get(OAUTH_TOKEN_CACHE_KEY)
    if token.nil?
      oauth = Koala::Facebook::OAuth.new(ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_APP_SECRET'])
      token = oauth.get_app_access_token
      @redis.set(OAUTH_TOKEN_CACHE_KEY, token)
      @redis.expire(OAUTH_TOKEN_CACHE_KEY, OAUTH_TOKEN_CACHE_EXPIRE)
    end

    token
  end

  def self.find_best_listings(client, model)
    lat = model['lat']
    lng = model['lng']
    title = model['title']

    response = client.search(title, { 
      fields: REQUEST_FIELDS.join(','),
      center: [lat, lng].join(','),
      type: 'place',
      distance: 10000,
    })

    puts "Search returned #{response.count} listings"
    listings = filter_listings(response) 

    if listings.empty?
      puts "Couldn't find anything using (lat, lng), trying global search"
      listings = client.search(title, { 
        fields: REQUEST_FIELDS.join(','),
        type: 'page'
      })
    end

    listings = filter_listings(response)
    listings
  end

  def self.filter_listings(listings)
    # Prefer claimed listings over unclaimed listings
    claimed, unclaimed = listings.partition do |result|
      !result['is_unclaimed']
    end
      
    puts "After filtering there are #{claimed.count} listings"
    if claimed.empty? && !unclaimed.empty?
      puts "No unfiltered listings remain, using filtered listings"
      claimed = unclaimed
    end

    claimed
  end

  def self.process_photos(photos, params = {})
    photos.each do |photo|
      photo_id = photo['id']
      (photo['images'] || []).take(MAX_PHOTOS_PER_ALBUM).each do |image|
        model = FacebookPhoto.from_response(image, params.merge(photo_id: photo_id))
        model.upsert(@connection, { 
          width: model.width, 
          height: model.height, 
          album_id: model.album_id,
          facebook_id: model.facebook_id, 
          photo_id: model.photo_id
        })
      end
    end
  end
end
