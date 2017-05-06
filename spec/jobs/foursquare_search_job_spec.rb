require File.expand_path '../../spec_helper.rb', __FILE__

describe FoursquareSearchJob do
  let(:foursquare) { double }
  before do
    FoursquareSearchJob.instance_variable_set("@foursquare", foursquare)
    
    Resque.stub(:enqueue)
  end

  describe '#perform' do
    let(:model) { {'title' => 'meow', 'lat' => 80.0, 'lng' => 80.0 } }
    context 'when there are no results' do
      let(:empty_foursquare_response) { double(venues: []) }
      it 'calls .search_by_coordinates on the client' do
        foursquare.should_receive(:search_venues)
          .with(hash_including(query: model['title'], ll: [model['lat'], model['lng']].join(', ')))
          .and_return(empty_foursquare_response)

        FoursquareSearchJob.perform(model)
      end
    end

    context 'when there are results' do
      let(:expected_id) { '123' }
      let(:location) { double(lat: 80.0, lng: 80.0) }
      let(:foursquare_venue) { double(stats: {}, contact: {}, url: 'url', location: location, name: 'Gracie Barra', id: expected_id) }
      let(:foursquare_response) { double(venues: [foursquare_venue]) } 

      before do
        foursquare.stub(:search_venues).and_return(foursquare_response)
      end
      
      context 'when the results are too far away from the location' do
        before { Math.stub(:circle_distance).and_return(100000.0) }
        it 'does not enqueue a job for the first listing' do
          Resque.should_not_receive(:enqueue).with(FoursquareFetchAndAssociateJob, hash_including(foursquare_id: expected_id))

          FoursquareSearchJob.perform(model)
        end
      end

      context 'when the results are not too far away from the location' do
        before { Math.stub(:circle_distance).and_return(0.0) }
        it 'enqueues an associate job for the first/best listing' do
          Resque.should_receive(:enqueue).with(FoursquareFetchAndAssociateJob, hash_including(foursquare_id: expected_id))

          FoursquareSearchJob.perform(model)
        end
      end
    end
  end
end
