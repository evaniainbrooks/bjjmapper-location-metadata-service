require 'net/http'
require 'json/ext'
require 'uri'

class AvatarService 
  API_KEY = "d72d574f-a395-419e-879c-2b2d39a51ffc"

  def initialize(host, port)
    @host = host
    @port = port
  end

  def set_profile_image(location_id, image_url)
    uri = URI("http://#{@host}:#{@port}/service/avatar/upload/locations/#{location_id}/url?api_key=#{API_KEY}")

    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Post.new(uri.request_uri)
    request.body = {url: image_url}.to_json
    request.content_type = 'application/json'

    begin
      response = http.request(request)
      unless response.code.to_i == 202
        puts "Unexpected response #{response.inspect}"
      end
      
      response.code.to_i
    rescue StandardError => e
      puts e.message
      return 500
    end
  end
end
