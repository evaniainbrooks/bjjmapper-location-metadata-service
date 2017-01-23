require File.expand_path '../../../spec_helper.rb', __FILE__

describe 'DetailResponse' do
  describe '#respond' do
    let(:title) { 'some title' }
    let(:address_components) { {
        title: title,
        lat: 80.0,
        lng: 80.0,
        street: 'street',
        city: 'San Diego',
        state: 'CA',
        country: 'US',
        postal_code: '98125'
    } }
    let(:address) { address_components.merge(as_json: address_components) }
    let(:listings) { { :google => double(address), :yelp => double(address) } }
    context 'with compare address' do
      let(:result) { Responses::DetailResponse.respond({address: address}, listings) }
      
      it 'returns a json blob' do
        JSON.parse(result).should_not be_nil
      end

      it 'returns the distance of the listing' do
        JSON.parse(result)[0]['distance'].should < 0.0005
      end

      it 'returns the difference of the listing address' do
        JSON.parse(result)[0]['address_levenshtein_distance'].should eq 0
      end
    end
    context 'with compare title' do
      let(:result) { Responses::DetailResponse.respond({title: title}, listings) }
      it 'returns the difference of the listing title' do
        JSON.parse(result)[0]['title_levenshtein_distance'].should eq 0
      end
    end
    context 'without compare address' do
      let(:result) { Responses::DetailResponse.respond({}, listings) }
      
      it 'returns a json blob' do
        JSON.parse(result).should_not be_nil
      end
    end
  end
end
