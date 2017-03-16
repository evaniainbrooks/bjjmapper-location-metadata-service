FactoryGirl.define do
  factory :google_review do
    place_id 'place123'
    coordinates [80.0, 80.0]
    author_name 'Evan'
    author_url 'url1234'
  end
end
