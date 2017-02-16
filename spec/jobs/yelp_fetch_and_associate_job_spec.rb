require File.expand_path '../../spec_helper.rb', __FILE__

describe YelpFetchAndAssociateJob do
  describe '#perform' do
    let(:yelp) { double }
    before { described_class.instance_variable_set("@client", yelp) }

    let(:lat) { 80.0 }
    let(:lng) { 80.0 }
    let(:yelp_id) { 'yelpid' }
    let(:loc_id) { 'locid' }
    let(:model) { { 'yelp_id' => yelp_id, 'bjjmapper_location_id' => loc_id } }
    let(:yelp_coordinates) { { 'latitude' => lat, 'longitude' => lng } }
    let(:yelp_business) { { 'id' => 'yelpid', 'coordinates' => yelp_coordinates, 'name' => 'yelp business' } }
    
    it 'searches yelp for the listing' do
      yelp.stub(:reviews)
      yelp.should_receive(:business).with(yelp_id).and_return(yelp_business)

      described_class.perform(model)
    end
    
    it 'fetches reviews for the listing' do
      yelp.stub(:business).and_return(yelp_business)
      yelp.should_receive(:reviews).with(yelp_id)

      described_class.perform(model)
    end

    it 'persists the yelp listing' do
      yelp.stub(:reviews)
      yelp.stub(:business).and_return(yelp_business)
      YelpBusiness.any_instance.should_receive(:upsert).with(anything,
        hash_including(bjjmapper_location_id: loc_id, yelp_id: yelp_id))

      described_class.perform(model)
    end
  end
end

