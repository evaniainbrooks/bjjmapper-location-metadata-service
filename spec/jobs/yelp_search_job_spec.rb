require File.expand_path '../../spec_helper.rb', __FILE__

describe YelpSearchJob do
  describe '#perform' do
    let(:model) { {'title' => 'meow', 'lat' => 80.0, 'lng' => 80.0 } }
    context 'when there are no results' do
      let(:empty_yelp_response) { double('yelp response', businesses: []) }
      it 'calls .search_by_coordinates on the client' do
        YelpSearchJob
          .instance_variable_get("@client")
          .should_receive(:search_by_coordinates)
          .with({latitude: model['lat'], longitude: model['lng']}, hash_including(term: model['title']))
          .and_return(empty_yelp_response)

        YelpSearchJob.perform(model)
      end
    end

    context 'when there are results' do
      let(:expected_id) { '123' }
      let(:yelp_response) { double('yelp response', businesses: [double('business', id: expected_id)]) }
      before do
        YelpSearchJob
          .instance_variable_get("@client")
          .stub(:search_by_coordinates)
          .and_return(yelp_response)
      end
      
      it 'calls .business on the client for the best (first) result' do
        YelpSearchJob
          .instance_variable_get("@client")
          .should_receive(:business)
          .with(expected_id)
          .and_return(double(business: OpenStruct.new))

        YelpSearchJob.perform(model)
      end
      
      it 'upserts the first listing' do
        YelpSearchJob
          .instance_variable_get("@client")
          .should_receive(:business)
          .with(expected_id)
          .and_return(double(business: OpenStruct.new(id: expected_id)))

        YelpBusiness.any_instance.should_receive(:upsert).with(anything, yelp_id: expected_id)

        YelpSearchJob.perform(model)
      end
    end
  end
end
