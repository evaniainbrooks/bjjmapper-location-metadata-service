require File.expand_path '../../spec_helper.rb', __FILE__

describe YelpSearchJob do
  let(:bjjmapper) { double }
  let(:yelp) { double }
  before do
    YelpSearchJob.instance_variable_set("@bjjmapper", bjjmapper)
    YelpSearchJob.instance_variable_set("@client", yelp)
    
    Resque.stub(:enqueue)
  end

  describe '#perform' do
    let(:model) { {'title' => 'meow', 'lat' => 80.0, 'lng' => 80.0 } }
    context 'when there are no results' do
      let(:empty_yelp_response) { { 'businesses' => [] } }
      it 'calls .search_by_coordinates on the client' do
        yelp.should_receive(:search)
          .with(hash_including({latitude: model['lat'], longitude: model['lng'], term: model['title']}))
          .and_return(empty_yelp_response)

        YelpSearchJob.perform(model)
      end
    end

    context 'when there are results' do
      let(:expected_id) { '123' }
      let(:yelp_coordinates) { { 'latitude' => 81.0, 'longitude' => 81.0 } }
      let(:yelp_business) { { 'id' => expected_id, 'coordinates' => yelp_coordinates, 'name' => 'yelp business' } }
      let(:yelp_response) { { 'businesses' => [yelp_business] } }
      let(:yelp_reviews) { { 'reviews' => [] } }

      before do
          yelp.stub(:search).and_return(yelp_response)
      end
      
      it 'enqueues an associate job for the first/best listing' do
        Resque.should_receive(:enqueue).with(YelpFetchAndAssociateJob, hash_including(yelp_id: expected_id))

        YelpSearchJob.perform(model)
      end

      # These tests need to be moved to the FetchAndAssociate spec
      xit 'calls .reviews on the client for the best (first) result' do
        yelp.stub(:business).and_return(yelp_business)
        yelp.should_receive(:reviews)
          .with(expected_id)
          .and_return(yelp_reviews)

        YelpSearchJob.perform(model)
      end
      
      xit 'upserts the first listing' do
        yelp.stub(:reviews)
        yelp.should_receive(:business)
          .with(expected_id)
          .and_return(yelp_business)

        YelpBusiness.any_instance.should_receive(:upsert).with(anything, yelp_id: expected_id)

        YelpSearchJob.perform(model)
      end
    end
  end
end
