require File.expand_path '../../spec_helper.rb', __FILE__

describe Address do
  let(:address_components) { {
      lat: 80.0,
      lng: 80.0,
      street: 'street',
      city: 'San Diego',
      state: 'CA',
      country: 'US',
      postal_code: '98125'
  } }
  subject { Address.new(address_components) }
  
  describe '.to_s' do
    it 'returns a string' do
      subject.to_s.should match "#{address_components[:street]}, #{address_components[:city]}"
    end
  end
  describe '.normalize' do
    it 'normalizes the address' do
      subject.normalize[:country].should match 'United States'
    end
  end
  describe '.distance' do
    it 'returns the levenshtein distance' do
      subject.distance(subject).should eq 0
    end
  end
end
