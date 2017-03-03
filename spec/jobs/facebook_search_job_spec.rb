require File.expand_path '../../spec_helper.rb', __FILE__

describe FacebookSearchJob do
  let(:mongo) { double }
  let(:redis) { double }
  before do
    FacebookSearchJob.instance_variable_set("@connection", mongo)
    FacebookSearchJob.instance_variable_set("@redis", redis)
  
    redis.stub(:get).and_return('oauth_token')
  end

  describe '#perform' do
    let(:expected_id) { '123' }
    let(:model) { { 'id' => expected_id, 'title' => 'meow', 'lat' => 80.0, 'lng' => 80.0 } }
    
    context 'when there are results' do
      let(:facebook_id) { 'fb321' }
      let(:facebook_page) { { 'id' => facebook_id  } }
      let(:facebook_response) { [facebook_page] }
      
      before { Koala::Facebook::API.any_instance.stub(:search).and_return(facebook_response) }
      
      it 'upserts the listing' do
        FacebookPage.any_instance.should_receive(:upsert).with(mongo, hash_including(bjjmapper_location_id: expected_id, facebook_id: facebook_id))

        FacebookSearchJob.perform(model)
      end
    end

    context 'when the profile image is not a silhouette' do
      let(:facebook_id) { 'fb321' }
      let(:expected_url) { 'url567' }
      let(:facebook_page) { { 'id' => facebook_id, 'picture' => { 'data' => { 'url' => expected_url } } } }
      let(:facebook_response) { [facebook_page] }
      
      before { Koala::Facebook::API.any_instance.stub(:search).and_return(facebook_response) }
      before do
        FacebookPage.any_instance.stub(:upsert)
        FacebookPhoto.any_instance.stub(:upsert)
        Resque.stub(:enqueue)
      end

      it 'upserts the image' do
        FacebookPhoto.any_instance.should_receive(:upsert).with(mongo, hash_including(is_profile_photo: true, facebook_id: facebook_id))

        FacebookSearchJob.perform(model)
      end

      it 'enqueues a set location image job' do
        Resque.should_receive(:enqueue).with(SetLocationImageJob, expected_id, expected_url)

        FacebookSearchJob.perform(model)
      end
    end
  end
end
