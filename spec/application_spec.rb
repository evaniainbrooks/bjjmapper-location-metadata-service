# spec/app_spec.rb
require File.expand_path '../spec_helper.rb', __FILE__

describe 'LocationFetchService' do
  context 'without api key' do
    it 'returns 401' do
      get '/search/async'
      last_response.status.should eq 401
    end
  end
  describe 'POST /search/async' do
    let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
    let(:common_params) { { api_key: LocationFetchService::APP_API_KEY } }
    let(:api_key) { LocationFetchService::APP_API_KEY }
    context 'without location parameter' do
      let(:request) { {} }
      it 'returns 400 bad request' do
        post "/search/async?api_key=#{api_key}", request
        last_response.status.should eq 400
      end
    end
    context 'with location.id parameter' do
      let(:request) { { location: { id: 123, lat: 80.0, lng: 80.0 }  }.to_json }
      context 'when a listing exists' do
        let(:spot) { double(place_id: 'abc') }
        before { GoogleSpot.stub(:find).and_return(spot) }
        it 'enqueues a refresh job for the listing' do
          Resque.should_receive(:enqueue).with(GoogleFetchAndAssociateJob, hash_including(place_id: spot.place_id, bjjmapper_location_id: 123))

          post "/search/async?api_key=#{api_key}&scope=google", request, content_type
          last_response.status.should eq 202
        end
      end
      
      context 'when no listings exist' do
        before do
          GoogleSpot.stub(:find).and_return(nil)
          YelpBusiness.stub(:find).and_return(nil)
          FacebookPage.stub(:find).and_return(nil)
        end
        context 'without scope parameter' do
          before do
            Resque.should_receive(:enqueue).with(GoogleSearchJob, anything)
            Resque.should_receive(:enqueue).with(YelpSearchJob, anything)
            Resque.should_receive(:enqueue).with(FacebookSearchJob, anything)
          end
          it 'enqueues search jobs and returns 202' do
            post "/search/async?api_key=#{api_key}", request, content_type
            last_response.status.should eq 202
          end
        end
        context 'with scope parameter' do
          before do
            Resque.should_receive(:enqueue).with(GoogleSearchJob, anything)
          end
          it 'enqueues search job for the scope and returns 202' do
            post "/search/async?api_key=#{api_key}&scope=google", request, content_type
            last_response.status.should eq 202
          end
        end
      end
    end
    context 'without location.id parameter' do
      let(:request) { { location: { lat: 80.0, lng: 80.0 }  }.to_json }
      context 'without scope paramter' do
        before do
          Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, anything)
          Resque.should_receive(:enqueue).with(YelpIdentifyCandidateLocationsJob, anything)
        end
        it 'enqueues an IdentifyCandidateLocationsJob and returns 202' do
          post "/search/async?api_key=#{api_key}", request, content_type
          last_response.status.should eq 202
        end
      end
      context 'with scope parameter' do
        before do
          Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, anything)
        end
        it 'enqueues search job for the scope and returns 202' do
          post "/search/async?api_key=#{api_key}&scope=google", request, content_type
          last_response.status.should eq 202
        end
      end
    end
  end
  describe 'GET /locations/:id/detail' do

  end
  describe 'GET /locations/:id/reviews' do

  end
  describe 'GET /locations/:id/photos' do

  end
end
