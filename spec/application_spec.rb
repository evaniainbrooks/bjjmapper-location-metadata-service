# spec/app_spec.rb
require File.expand_path '../spec_helper.rb', __FILE__

describe 'LocationFetchService' do
  context 'without api key' do
    it 'returns 401' do
      get '/search/async'
      last_response.status.should eq 401
    end
  end
  
  let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:common_params) { { api_key: LocationFetchService::APP_API_KEY } }
  let(:api_key) { LocationFetchService::APP_API_KEY }
  
  describe 'POST /locations/:bjjmapper_location_id/search' do
    let(:location_id) { 'abc123' }
    let(:request) { { location: { id: location_id, lat: 80.0, lng: 80.0 }  }.to_json }
    
    context 'without location parameter' do
      let(:empty_request) { {} }
      let(:spot) { double(place_id: 'abc') }
      before { GoogleSpot.stub(:find).and_return(spot) }
      it 'returns 400 bad request' do
        post "/locations/#{location_id}/search?api_key=#{api_key}", empty_request
        last_response.status.should eq 400
      end
    end
    
    context 'when a listing exists' do
      let(:spot) { double(place_id: 'abc') }
      before { GoogleSpot.stub(:find).and_return(spot) }
      it 'enqueues a refresh job for the listing' do
        Resque.should_receive(:enqueue).with(GoogleFetchAndAssociateJob, hash_including(place_id: spot.place_id, bjjmapper_location_id: location_id))

        post "/locations/#{location_id}/search?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 202
      end
    end
    
    context 'when no listings exist' do
      before do
        GoogleSpot.stub(:find).and_return(nil)
        YelpBusiness.stub(:find).and_return(nil)
        FacebookPage.stub(:find).and_return(nil)
      end
      it 'returns 404 not found' do
        post "/locations/#{location_id}/search?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 404
      end
    end
  end

  describe 'POST /locations/search' do
    let(:request) { { location: { lat: 80.0, lng: 80.0 }  }.to_json }
    context 'without scope paramter' do
      before do
        Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, anything)
        Resque.should_receive(:enqueue).with(YelpIdentifyCandidateLocationsJob, anything)
      end
      it 'enqueues an IdentifyCandidateLocationsJob and returns 202' do
        post "/locations/search?api_key=#{api_key}", request, content_type
        last_response.status.should eq 202
      end
    end
    context 'with scope parameter' do
      before do
        Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, anything)
      end
      it 'enqueues search job for the scope and returns 202' do
        post "/locations/search?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 202
      end
    end
  end
  describe 'GET /locations/reviews' do
    let(:request) { { :lat => 80.0, :lng => 80.0 } }
    let(:review) { GoogleReview.new }
    before { GoogleReview.stub(:find_all).and_return([review]) }
    it 'returns reviews near lat lng' do
      get "/locations/reviews?api_key=#{api_key}", request, content_type
      last_response.status.should eq 200
    end
  end
  describe 'GET /locations/photos' do
    let(:request) { { :lat => 80.0, :lng => 80.0 } }
    let(:photo) { GooglePhoto.new }
    before { GooglePhoto.stub(:find_all).and_return([photo]) }
    it 'returns reviews near lat lng' do
      get "/locations/photos?api_key=#{api_key}", request, content_type
      last_response.status.should eq 200
    end
  end
  describe 'GET /locations/:id' do

  end
  describe 'GET /locations/:id/listings' do

  end
  describe 'GET /locations/:id/reviews' do

  end
  describe 'GET /locations/:id/photos' do

  end
end
