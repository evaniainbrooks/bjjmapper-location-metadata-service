FactoryGirl.define do
  factory :google_photo do
    place_id 'place123'
    coordinates [80.0, 80.0]
    url 'someurl'
    large_url 'somelargeurl'
    width 100
    height 100
  end
end
