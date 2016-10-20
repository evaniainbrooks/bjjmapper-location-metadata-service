require './app/models/base_model'

class Spot < BaseModel
  COLLECTION_NAME = 'google_places_spots'

  #<GooglePlaces::Spot:0x000000010d83a0 @reference="CmRSAAAAy8nBfMqXYUagXZobE6bzPNcniB55hNd_AdSoGgwEPiiUZZnlsqqc1MLyxLZ1ooDIeIQPS_FsZKcviiDCIpFMB6_sJjto1-5mu9BDHqKxEPmNAWmyiip7BACQVNDyYCydEhBh9aWvrwd8iUm3bWHsP487GhT3YMetfuailWzMMl-htNvyriBAuQ", @place_id="ChIJkzulmVQUkFQR09X0Gx3j178", @vicinity="4211 Winslow Place North, Seattle", @lat=47.6581137, @lng=-122.3470205, @viewport={"northeast"=>{"lat"=>47.65815779999999, "lng"=>-122.34655055}, "southwest"=>{"lat"=>47.65809900000001, "lng"=>-122.34717715}}, @name="Marcelo Alonso Brazilian Jiu-Jitsu Carlson Gracie Team", @icon="https://maps.gstatic.com/mapfiles/place_api/icons/school-71.png", @types=["gym", "health", "point_of_interest", "establishment"], @id="849cb86de16d98be88142c30f267c219f03db7dd", @formatted_phone_number=nil, @international_phone_number=nil, @formatted_address=nil, @address_components=nil, @street_number=nil, @street=nil, @city=nil, @region=nil, @postal_code=nil, @country=nil, @rating=4.7, @price_level=nil, @opening_hours={"open_now"=>false, "weekday_text"=>[]}, @url=nil, @cid=0, @website=nil, @zagat_reviewed=nil, @zagat_selected=nil, @aspects=[], @review_summary=nil, @photos=[#<GooglePlaces::Photo:0x000000010d7a18 @width=720, @height=480, @photo_reference="CoQBcwAAAKUJMEs1RPfsNx_PhG1CEZidamlVPIsLeuJxQlWNVa95UfpYx52o03IgQfU46AjWTHMepD7JkkBvdTYEAbucGINreC64VL6p7St5ymVLGJPSqtvpj3lToRNA_tMU2iDtlU3de64OBDpE_By6AH3xK-D-9Tztda1oRAXw4IwEG-FbEhDzcMbIDd9AS5g6WR2QQvBmGhT1_vSrbgT6_gPb4w6s9ymHrAjtgg", @html_attributions=["<a href=\"https://maps.google.com/maps/contrib/115601079111767090095/photos\">Marcelo Alonso Brazilian Jiu-Jitsu Carlson Gracie Team</a>"], @api_key="AIzaSyAuLA-LpDpafAs7p0XH4nE8yj__Rr2oD0s">], @reviews=[], @nextpagetoken=nil, @events=[], @utc_offset=nil>

  attr_accessor  :lat, :lng, :viewport, :name, :icon, :reference, :vicinity, :types, :id,
                 :formatted_phone_number, :international_phone_number, :formatted_address,
                 :address_components, :street_number, :street, :city, :region, :postal_code,
                 :country, :rating, :url, :cid, :website, :aspects, :zagat_selected,
                 :zagat_reviewed, :review_summary, :nextpagetoken, :price_level,
                 :opening_hours, :events, :utc_offset, :place_id

  attr_accessor  :_id, :bjjmapper_location_id, :batch_id
end
