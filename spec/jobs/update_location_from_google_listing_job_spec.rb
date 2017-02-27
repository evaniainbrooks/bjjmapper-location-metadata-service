require File.expand_path '../../spec_helper.rb', __FILE__

describe UpdateLocationFromGoogleListingJob do
  let(:bjjmapper) { double }
  let(:connection) { double }
  before do
    described_class.instance_variable_set("@bjjmapper", bjjmapper)
    described_class.instance_variable_set("@connection", connection)
  end

  describe '#perform' do
    let(:locid) { '1234' }
    let(:model) { { 'bjjmapper_location_id' => locid } }
    let(:spot) { double(address_components: {}, lat: 80.0, lng: 80.0) }
    it 'calls update_location' do
      GoogleSpot.should_receive(:find).with(connection, hash_including(bjjmapper_location_id: locid)).and_return(spot)
      bjjmapper.should_receive(:update_location).with(locid, anything)

      described_class.perform(model)
    end
  end
end
