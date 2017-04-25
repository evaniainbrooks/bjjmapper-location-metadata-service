# spec/app_spec.rb
require File.expand_path '../spec_helper.rb', __FILE__

describe 'LocationFetchService' do
  context 'without api key' do
    it 'returns 401' do
      get '/search/async'
      last_response.status.should eq 401
    end
  end
  
  let(:location_id) { 'abc123' }
  let(:content_type) { { 'CONTENT_TYPE' => 'application/json' } }
  let(:common_params) { { api_key: LocationFetchService::APP_API_KEY } }
  let(:api_key) { LocationFetchService::APP_API_KEY }
  
  describe 'POST /locations/:bjjmapper_location_id/search' do
    let(:request) { { location: { id: location_id, lat: 80.0, lng: 80.0 }  }.to_json }
    
    context 'without location parameter' do
      let(:empty_request) { {} }
      let(:spot) { build(:google_spot) }
      before { GoogleSpot.stub(:find).and_return(spot) }
      it 'returns 400 bad request' do
        post "/locations/#{location_id}/search?api_key=#{api_key}", empty_request
        last_response.status.should eq 400
      end
    end
    
    context 'when a listing exists' do
      let(:spot) { build(:google_spot) } 
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
      it 'enqueues a search job' do
        Resque.should_receive(:enqueue).with(GoogleSearchJob, anything)

        post "/locations/#{location_id}/search?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 202
      end
    end
  end

  describe 'POST /search' do
    let(:request_data) { { 'lat' => 80.0, 'lng' => 80.0 } }
    let(:request) { { location: request_data }.to_json }
    context 'without scope paramter' do
      before do
        Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, hash_including(request_data))
        Resque.should_receive(:enqueue).with(YelpIdentifyCandidateLocationsJob, hash_including(request_data))
      end
      
      it 'enqueues an IdentifyCandidateLocationsJob and returns 202' do
        post "/search?api_key=#{api_key}", request, content_type
        last_response.status.should eq 202
      end
    end
    
    context 'with scope parameter' do
      before do
        Resque.should_receive(:enqueue).with(GoogleIdentifyCandidateLocationsJob, hash_including(request_data))
      end
      
      it 'enqueues search job for the scope and returns 202' do
        post "/search?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 202
      end
    end
  end
  
  describe 'GET /reviews' do
    let(:request) { { :lat => 80.0, :lng => 80.0 } }
    let(:review) { build(:google_review) } 
    before do
      GoogleReview.stub(:find_all).and_return([review])
      YelpReview.stub(:find_all).and_return([])
    end
    
    it 'returns reviews near lat lng' do
      get "/reviews?api_key=#{api_key}", request, content_type
      last_response.status.should eq 200
    end
  end
  
  describe 'GET /photos' do
    let(:request) { { :lat => 80.0, :lng => 80.0 } }
    let(:photo) { build(:google_photo) }
    before do
      GooglePhoto.stub(:find_all).and_return([photo])
      YelpPhoto.stub(:find_all).and_return([])
      FacebookPhoto.stub(:find_all).and_return([])
    end
    
    it 'returns reviews near lat lng' do
      get "/photos?api_key=#{api_key}", request, content_type
      last_response.status.should eq 200
    end
  end
  
  describe 'GET /locations/:id' do
    let(:request) { } 
    
    context 'without listings' do
      before { GoogleSpot.stub(:find).and_return(nil) }
      
      it 'returns 404' do
        get "/locations/#{location_id}?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 404
      end
    end
    
    context 'with listings' do
      let(:listing) { build(:google_spot) }
      before { GoogleSpot.stub(:find).and_return(listing) }
      
      it 'returns associated listing information' do
        get "/locations/#{location_id}?api_key=#{api_key}&scope=google", request, content_type
        
        last_response.status.should eq 200
        last_response.body.should match(listing.name)
      end
    end
  end
  
  describe 'GET /locations/:id/listings' do
    let(:request) { } 
    
    context 'without listings' do
      before do
        GoogleSpot.stub(:find_all).and_return([])
        FacebookPage.stub(:find_all).and_return([])
        YelpBusiness.stub(:find_all).and_return([])
      end
      
      it 'returns 404' do
        get "/locations/#{location_id}/listings?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 404
      end
    end

    context 'with listings' do
      let(:listings) { [build(:google_spot, name: 'name1'), build(:google_spot, name: 'name2')] }
      before do
        GoogleSpot.stub(:find_all).and_return(listings)
        FacebookPage.stub(:find_all).and_return([])
        YelpBusiness.stub(:find_all).and_return([])
      end
      
      it 'returns all listing information' do
        get "/locations/#{location_id}/listings?api_key=#{api_key}&scope=google", request, content_type
        
        last_response.status.should eq 200
        last_response.body.should match(listings[0].name)
        last_response.body.should match(listings[1].name)
      end
    end
  end
  
  describe 'GET /locations/:id/reviews' do
    let(:request) { { :lat => 80.0, :lng => 80.0 } } 
    
    context 'with reviews' do
      let(:listing) { build(:google_spot) }
      let(:reviews) { [build(:google_review)] }
      
      before do
        GoogleSpot.stub(:find).and_return(listing)
        GoogleReview.stub(:find_all).and_return(reviews)
      end
      
      it 'returns all reviews for the location' do
        get "/locations/#{location_id}/reviews?api_key=#{api_key}&scope=google", request, content_type
        
        last_response.status.should eq 200
        last_response.body.should match(reviews[0].author_name)
      end
    end
    
    context 'without listings' do
      before do
        GoogleSpot.stub(:find).and_return(nil)
        GoogleReview.stub(:find_all).and_return([])
      end
      
      it 'returns 404' do
        get "/locations/#{location_id}/reviews?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 404
      end
    end
  end
  
  describe 'GET /locations/:id/photos' do
    let(:request) { } 
    
    context 'with listings' do
      let(:listing) { build(:google_spot) }
      let(:photos) { [build(:google_photo)] }
      
      before do
        GoogleSpot.stub(:find).and_return(listing)
        GooglePhoto.stub(:find_all).and_return(photos)
      end
      
      it 'returns all photos for the location' do
        get "/locations/#{location_id}/photos?api_key=#{api_key}&scope=google", request, content_type
        
        last_response.status.should eq 200
        last_response.body.should match(photos[0].url)
      end
    end
    
    context 'without listings' do
      before do
        GoogleSpot.stub(:find).and_return nil
        GoogleReview.stub(:find_all).and_return []
      end

      it 'returns 404' do
        get "/locations/#{location_id}/photos?api_key=#{api_key}&scope=google", request, content_type
        last_response.status.should eq 404
      end
    end
  end
end
