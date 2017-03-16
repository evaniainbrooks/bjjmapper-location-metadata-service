FactoryGirl.define do
  factory :google_spot do
    name 'Google spot'
    place_id 'place123'
    coordinates [80.0, 80.0]
    country 'Canada'
    city 'Halifax'
  end
end
