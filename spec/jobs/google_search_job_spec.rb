require File.expand_path '../../spec_helper.rb', __FILE__

describe GoogleSearchJob do
  let(:google) { double }
  before do
    GoogleSearchJob.instance_variable_set("@places_client", google)
    
    Resque.stub(:enqueue)
  end

  describe '#perform' do
    let(:model) { {'title' => 'meow', 'lat' => 80.0, 'lng' => 80.0 } }
    context 'when there are no results' do
      let(:empty_google_response) { [] }
      it 'calls .search_by_coordinates on the client' do
        google.should_receive(:spots)
          .with(model['lat'], model['lng'], hash_including(name: model['title']))
          .and_return(empty_google_response)

        GoogleSearchJob.perform(model)
      end
    end

    context 'when there are results' do
      let(:expected_id) { '123' }
      let(:google_spot) { double(lat: 80.0, lng: 80.0, name: 'Gracie Barra', place_id: expected_id) }
      let(:google_response) { [google_spot] } 

      before do
        google.stub(:spots).and_return(google_response)
      end
      
      context 'when the results are too far away from the location' do
        before { Math.stub(:circle_distance).and_return(100000.0) }
        it 'does not enqueue a job for the first listing' do
          Resque.should_not_receive(:enqueue).with(GoogleFetchAndAssociateJob, hash_including(place_id: expected_id))

          GoogleSearchJob.perform(model)
        end
      end

      context 'when the results are not too far away from the location' do
        before { Math.stub(:circle_distance).and_return(0.0) }
        it 'enqueues an associate job for the first/best listing' do
          Resque.should_receive(:enqueue).with(GoogleFetchAndAssociateJob, hash_including(place_id: expected_id))

          GoogleSearchJob.perform(model)
        end
      end
    end
  end
end
