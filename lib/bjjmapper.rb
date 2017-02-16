require 'net/http'
require 'json/ext'
require 'uri'

class BJJMapper
  API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"

  def initialize(host, port)
    @host = host
    @port = port
  end

  def create_review(location_id, review_data)
    query = {api_key: API_KEY}
    uri = URI("http://#{@host}:#{@port}/api/locations/#{location_id}/reviews.json?api_key=#{API_KEY}")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = { :review => review_data }.to_json
    request.content_type = 'application/json'

    begin
      response = http.request(request)
      unless response.code.to_i == 200
        puts "Unexpected response #{response.inspect}"
        return nil
      end

      JSON.parse(response.body)
    rescue StandardError => e
      puts e.message
      nil
    end
  end
  
  LOCATION_STATUS_PENDING = 1
  LOCATION_STATUS_VERIFIED = 2
  LOCATION_STATUS_REJECTED = 3
  def create_location(location_data)
    query = {api_key: API_KEY}
    uri = URI("http://#{@host}:#{@port}/api/locations.json?api_key=#{API_KEY}")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = {location: location_data}.to_json
    request.content_type = 'application/json'

    begin
      response = http.request(request)
      unless response.code.to_i == 200
        puts "Unexpected response #{response.inspect}"
        return nil
      end
      
      JSON.parse(response.body)
    rescue StandardError => e
      puts e.message
      nil
    end
  end
  
  def random_location(params = {})
    query = params.merge(:api_key => API_KEY, :count => 100, :rejected => 0, :closed => 0, :unverified => 0)
    query = URI.encode_www_form(query)
    uri = URI("http://#{@host}:#{@port}/api/locations/random.json?#{query}")

    get_request(uri)
  end

  def map_search(params)
    query = params.merge(:api_key => API_KEY, :count => 100, :rejected => 1, :closed => 1, :unverified => 1)
    query = URI.encode_www_form(query)
    uri = URI("http://#{@host}:#{@port}/api/locations.json?#{query}")

    get_request(uri)
  end

  private
    
  def get_request(uri)
    begin
      response = Net::HTTP.get_response(uri)
      return nil unless response.code.to_i == 200
      
      JSON.parse(response.body)
    rescue StandardError => e
      puts e.message
      nil
    end
  end
end
