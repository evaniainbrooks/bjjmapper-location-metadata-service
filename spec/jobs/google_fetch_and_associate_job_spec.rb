require File.expand_path '../../spec_helper.rb', __FILE__

describe GoogleFetchAndAssociateJob do
  describe '#perform' do
    let(:google) { double }
    before { described_class.instance_variable_set("@places_client", google) }
    before { Resque.stub(:enqueue) }

    let(:lat) { 80.0 }
    let(:lng) { 80.0 }
    let(:google_id) { 'googleid' }
    let(:loc_id) { 'locid' }
    let(:model) { { 'place_id' => google_id, 'bjjmapper_location_id' => loc_id } }
    let(:google_business) { double(photos: [], reviews: [], place_id: 'googleid', lat: lat, lng: lng, name: 'google business') }
    
    it 'searches google for the listing' do
      google.should_receive(:spot).with(google_id).and_return(google_business)

      described_class.perform(model)
    end
    
    it 'fetches reviews for the listing' do
      google.stub(:spot).and_return(google_business)
      google_business.should_receive(:reviews)

      described_class.perform(model)
    end
    
    it 'fetches photos for the listing' do
      google.stub(:spot).and_return(google_business)
      google_business.should_receive(:photos)

      described_class.perform(model)
    end

    it 'persists the google listing' do
      google.stub(:spot).and_return(google_business)
      GoogleSpot.any_instance.should_receive(:upsert).with(anything,
        hash_including(bjjmapper_location_id: loc_id, place_id: google_id))

      described_class.perform(model)
    end
  end
end

