require File.expand_path '../../spec_helper.rb', __FILE__

describe GoogleIdentifyCandidateLocationsJob do
  describe '#perform' do
    let(:bjjmapper) { double }
    let(:google_places) { double }
    before do
      GoogleIdentifyCandidateLocationsJob.instance_variable_set("@bjjmapper", bjjmapper)
      GoogleIdentifyCandidateLocationsJob.instance_variable_set("@places_client", google_places)
    end

    def stub_bjjmapper_search(response = [])
      bjjmapper.should_receive(:map_search)
        .with(hash_including({sort: 'distance', distance: GoogleIdentifyCandidateLocationsJob::DISTANCE_THRESHOLD_MI, lat: listing_lat, lng: listing_lng})) 
        .and_return(response)
    end

    def stub_google_search(response = [])
      google_places.should_receive(:spots)
        .and_return(response)
    end

    let(:lat) { 80.0 }
    let(:lng) { 80.0 }
    let(:listing_lat) { 47.0 }
    let(:listing_lng) { -122.0 }
    let(:model) { {'title' => 'meow', 'lat' => lat, 'lng' => lng } }
    let(:google_business) { double(place_id: 'google1234', lat: listing_lat, lng: listing_lng, name: 'google business') }
    let(:google_response) { [google_business] }
    
    it 'searches google for listings' do
      stub_google_search([])

      GoogleIdentifyCandidateLocationsJob.perform(model)
    end
    
    it 'searches bjj mapper for nearby locations' do
      stub_google_search(google_response)
      stub_bjjmapper_search
      bjjmapper.stub(:create_pending_location).and_return(model)

      GoogleIdentifyCandidateLocationsJob.perform(model)
    end

    context 'with listings' do
      context 'when there are nearby bjjmapper locations' do
        let(:closest_location) { { 'id' => 'locid', 'lat' => lat, 'lng' => lng } }
        before do 
          stub_bjjmapper_search([closest_location])
          stub_google_search(google_response)
        end
        it 'enqueues a fetch and associate job for the closest location' do
          Resque.should_receive(:enqueue).with(GoogleFetchAndAssociateJob, hash_including(bjjmapper_location_id: closest_location['id'], place_id: google_business.place_id))

          GoogleIdentifyCandidateLocationsJob.perform(model)
        end
      end
      context 'when there are no nearby bjjmapper locations' do
        let(:location_response) { { 'title' => 'somelocation', 'id' => 'new_locid', 'lat' => lat, 'lng' => lng } }
        before do
          stub_bjjmapper_search
          stub_google_search(google_response)
        end
        it 'creates a pending location' do
          bjjmapper.should_receive(:create_pending_location)
            .with(hash_including(title: google_business.name))
            .and_return(location_response)

          GoogleIdentifyCandidateLocationsJob.perform(model)
        end
        it 'persists the listing with the newly created location' do
          bjjmapper.stub(:create_pending_location).and_return(location_response)
          GooglePlacesSpot.any_instance.should_receive(:upsert).with(anything, place_id: google_business.place_id)

          GoogleIdentifyCandidateLocationsJob.perform(model)
        end
      end
    end
  end
end
