require "json"
require "http"

class YelpFusionClient
  # Constants, do not change these
  API_HOST = "https://api.yelp.com"
  SEARCH_PATH = "/v3/businesses/search"
  BUSINESS_PATH = "/v3/businesses/"  # trailing / because we append the business id to the path
  TOKEN_PATH = "/oauth2/token"
  GRANT_TYPE = "client_credentials"

  DEFAULT_SEARCH_LIMIT = 20

  def initialize(client_id, client_secret)
    @client_id = client_id
    @client_secret = client_secret
  end

  # Make a request to the Fusion search endpoint. Full documentation is online at:
  # https://www.yelp.com/developers/documentation/v3/business_search
  #
  # term - search term used to find businesses
  # location - what geographic location the search should happen
  #
  # Examples
  #
  #   search("burrito", "san francisco")
  #   # => {
  #          "total": 1000000,
  #          "businesses": [
  #            "name": "El Farolito"
  #            ...
  #          ]
  #        }
  #
  #   search("sea food", "Seattle")
  #   # => {
  #          "total": 1432,
  #          "businesses": [
  #            "name": "Taylor Shellfish Farms"
  #            ...
  #          ]
  #        }
  #
  # Returns a parsed json object of the request
  def search(params)
    url = "#{API_HOST}#{SEARCH_PATH}"
    default_params = { limit: DEFAULT_SEARCH_LIMIT }

    response = HTTP.auth(bearer_token).get(url, params: default_params.merge(params))
    response.parse
  end


  # Look up a business by a given business id. Full documentation is online at:
  # https://www.yelp.com/developers/documentation/v3/business
  # 
  # business_id - a string business id
  #
  # Examples
  # 
  #   business("yelp-san-francisco")
  #   # => {
  #          "name": "Yelp",
  #          "id": "yelp-san-francisco"
  #          ...
  #        }
  #
  # Returns a parsed json object of the request
  def business(business_id)
    url = "#{API_HOST}#{BUSINESS_PATH}#{business_id}"

    response = HTTP.auth(bearer_token).get(url)
    response.parse
  end
  
  def reviews(business_id)
    url = "#{API_HOST}#{BUSINESS_PATH}#{business_id}/reviews"

    response = HTTP.auth(bearer_token).get(url)
    response.parse
  end
  
  private

  # Make a request to the Fusion API token endpoint to get the access token.
  # 
  # host - the API's host
  # path - the oauth2 token path
  #
  # Examples
  #
  #   bearer_token
  #   # => "Bearer some_fake_access_token"
  #
  # Returns your access token
  def bearer_token
    @_bearer_token ||= begin
      # Put the url together
      url = "#{API_HOST}#{TOKEN_PATH}"

      raise "Please set your CLIENT_ID" if @client_id.nil?
      raise "Please set your CLIENT_SECRET" if @client_secret.nil?

      # Build our params hash
      params = {
        client_id: @client_id,
        client_secret: @client_secret,
        grant_type: GRANT_TYPE
      }

      response = HTTP.post(url, params: params)
      parsed = response.parse

      "#{parsed['token_type']} #{parsed['access_token']}"
    end
  end
end