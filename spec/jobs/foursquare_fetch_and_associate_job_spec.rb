require File.expand_path '../../spec_helper.rb', __FILE__

describe FoursquareFetchAndAssociateJob do
  describe '#perform' do
    let(:foursquare) { double }
    before { described_class.instance_variable_set("@foursquare", foursquare) }
    before { Resque.stub(:enqueue) }

    let(:lat) { 80.0 }
    let(:lng) { 80.0 }
    let(:foursquare_id) { 'foursquareid' }
    let(:loc_id) { 'locid' }
    let(:model) { { 'foursquare_id' => foursquare_id, 'bjjmapper_location_id' => loc_id } }
    let(:location) { double(lat: lat, lng: lng) }
    let(:foursquare_venue) { double(stats: {}, contact: {}, url: 'url', location: location, id: foursquare_id, name: 'foursquare venue') }
   
    before do
      foursquare_venue.stub(:photos)
      foursquare_venue.stub(:bestPhoto)
    end

    it 'searches foursquare for the listing' do
      foursquare.should_receive(:venue).with(foursquare_id, anything).and_return(foursquare_venue)

      described_class.perform(model)
    end
    
    it 'fetches photos for the listing' do
      foursquare.stub(:venue).and_return(foursquare_venue)
      foursquare_venue.should_receive(:photos)

      described_class.perform(model)
    end

    it 'persists the foursquare listing' do
      foursquare.stub(:venue).and_return(foursquare_venue)
      FoursquareVenue.any_instance.should_receive(:upsert).with(anything,
        hash_including(bjjmapper_location_id: loc_id, foursquare_id: foursquare_id))

      described_class.perform(model)
    end
  end
end

