require File.expand_path '../../spec_helper.rb', __FILE__

describe YelpIdentifyCandidateLocationsJob do
  describe '#perform' do
    let(:bjjmapper) { double }
    let(:yelp) { double }
    before do
      YelpIdentifyCandidateLocationsJob.instance_variable_set("@bjjmapper", bjjmapper)
      YelpIdentifyCandidateLocationsJob.instance_variable_set("@client", yelp)
    end

    def stub_bjjmapper_search(response = nil)
      bjjmapper.should_receive(:map_search)
        .with(hash_including({lat: model['lat'], lng: model['lng']}))
        .and_return(response)
    end

    def stub_yelp_search(response = OpenStruct.new)
      yelp.should_receive(:search_by_coordinates)
        .and_return(response)
    end

    let(:lat) { 80.0 }
    let(:lng) { 80.0 }
    let(:model) { {'title' => 'meow', 'lat' => lat, 'lng' => lng } }
    let(:empty_yelp_response) { double('empty yelp response', businesses: []) }
    let(:yelp_coordinates) { double(coordinate: double(latitude: lat, longitude: lng)) }
    let(:yelp_business) { double(id: 'yelp1234', location: yelp_coordinates, name: 'yelp business') }
    let(:yelp_response) { double('yelp response', businesses: [yelp_business]) }
    
    it 'searches yelp for listings' do
      stub_yelp_search

      YelpIdentifyCandidateLocationsJob.perform(model)
    end
    
    it 'searches bjj mapper for nearby locations' do
      stub_yelp_search(yelp_response)
      stub_bjjmapper_search
      bjjmapper.stub(:create_pending_location).and_return(model)

      YelpIdentifyCandidateLocationsJob.perform(model)
    end

    context 'with listings' do
      context 'when there are nearby bjjmapper locations' do
        let(:closest_location) { { 'id' => 'locid', 'lat' => lat, 'lng' => lng } }
        before do 
          stub_bjjmapper_search({ 'locations' => [closest_location] })
          stub_yelp_search(yelp_response)
        end
        it 'enqueues a fetch and associate job for the closest location' do
          Resque.should_receive(:enqueue).with(YelpFetchAndAssociateJob, hash_including(bjjmapper_location_id: closest_location['id'], yelp_id: yelp_business.id))

          YelpIdentifyCandidateLocationsJob.perform(model)
        end
      end
      context 'when there are no nearby bjjmapper locations' do
        let(:location_response) { { 'title' => 'somelocation', 'id' => 'new_locid', 'lat' => lat, 'lng' => lng } }
        before do
          stub_bjjmapper_search
          stub_yelp_search(yelp_response)
        end
        it 'creates a pending location' do
          bjjmapper.should_receive(:create_pending_location)
            .with(hash_including(title: yelp_business.name))
            .and_return(location_response)

          YelpIdentifyCandidateLocationsJob.perform(model)
        end
        it 'persists the listing with the newly created location' do
          bjjmapper.stub(:create_pending_location).and_return(location_response)
          YelpBusiness.any_instance.should_receive(:upsert).with(anything, yelp_id: yelp_business.id)

          YelpIdentifyCandidateLocationsJob.perform(model)
        end
      end
    end
  end
end

