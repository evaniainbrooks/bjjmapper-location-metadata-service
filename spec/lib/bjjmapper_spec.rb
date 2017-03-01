require File.expand_path '../../spec_helper.rb', __FILE__

describe BJJMapper do
  subject { BJJMapper.new('localhost', 9999) }
  describe '.create_review' do
    context 'with success response' do
      let(:review) { { :body => 'meow meow', :author_name => 'Evan', :author_link => 'BJJmapper.com', :rating => 5, :created_at => Time.now }.to_json }
      let(:response) { double('http_response', code: 200, body: review) }
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_return(response) }
      it 'fetches the response from the service' do
        subject.create_review(123, review).should eq JSON.parse(review)
      end
    end
    context 'when the service is down' do
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_raise(StandardError, 'service is down') }
      it 'returns nil' do
        subject.create_review(123, {}).should be_nil 
      end
    end
  end
  describe '.create_location' do
    let(:request) { { title: 'blah' } }
    context 'with success response' do
      let(:location_response) { { id: '1234', title: 'Hello Kitty', city: 'Halifax', country: 'Canada' }.to_json }
      let(:response) { double('http_response', code: 200, body: location_response) }
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_return(response) }
      it 'fetches the response from the service' do
        subject.create_location(request).should eq JSON.parse(location_response)
      end
    end
    context 'when the service is down' do
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_raise(StandardError, 'service is down') }
      it 'returns nil' do
        subject.create_location(request).should be_nil 
      end
    end
  end
  describe '.update_location' do
    let(:request) { { title: 'blah' } }
    context 'with success response' do
      let(:location_response) { { id: '1234', title: 'Hello Kitty', city: 'Halifax', country: 'Canada' }.to_json }
      let(:response) { double('http_response', code: 200, body: location_response) }
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Put)).and_return(response) }
      it 'fetches the response from the service' do
        subject.update_location('id', request).should eq JSON.parse(location_response)
      end
    end
    context 'when the service is down' do
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Put)).and_raise(StandardError, 'service is down') }
      it 'returns nil' do
        subject.update_location('id', request).should be_nil 
      end
    end
  end
  describe '.map_search' do
    context 'with success response' do
      let(:expected_response) { { lat: 80.0, lng: 80.0, locations: [] }.to_json }
      let(:response) { double('http_response', :code => 200, :body => expected_response) }
      before { Net::HTTP.should_receive(:get_response).and_return(response) }
      it 'returns the response' do
        subject.map_search({}).should eq JSON.parse(expected_response)
      end
    end
    context 'with failure response' do
      let(:response) { double('http_response', :code => 400, :body => '{}') }
      before { Net::HTTP.should_receive(:get_response).and_return(response) }
      it 'returns nil' do
        subject.map_search({}).should be_nil
      end
    end
    context 'when the service is down' do
      before { Net::HTTP.should_receive(:get_response).and_raise(StandardError, 'service is down') }
      it 'returns nil' do
        subject.map_search({}).should be_nil
      end
    end
  end
end
