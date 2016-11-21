require 'net/http'
require 'json/ext'
require 'uri'

class BJJMapper
  API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"

  def initialize(host, port)
    @host = host
    @port = port
  end

  def create_pending_location(location_data)
    query = {api_key: API_KEY}
    uri = URI("http://#{@host}:#{@port}/locations.json?api_key=#{API_KEY}")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = {location: location_data.merge(status: 1)}.to_json
    request.content_type = 'application/json'

    begin
      response = http.request(request)
      return nil unless response.code.to_i == 200
      
      JSON.parse(response.body)
    rescue StandardError => e
      puts e.message
      nil
    end
  end

  def map_search(params)
    query = params.merge(:api_key => API_KEY, :rejected => 1, :closed => 1, :unverified => 1, :'location_type[]' => 1)
    query = URI.encode_www_form(query)
    uri = URI("http://#{@host}:#{@port}/map/search.json?#{query}")

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
