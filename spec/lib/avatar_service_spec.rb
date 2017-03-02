require File.expand_path '../../spec_helper.rb', __FILE__

describe AvatarService do
  subject { AvatarService.new('localhost', 9999) }
  describe '.create_location' do
    context 'with success response' do
      let(:response) { double('http_response', code: 202, body: nil) }
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_return(response) }
      it 'fetches the response from the service' do
        subject.set_profile_image('123', 'url').should eq 202
      end
    end
    context 'when the service is down' do
      before { Net::HTTP.any_instance.should_receive(:request).with(instance_of(Net::HTTP::Post)).and_raise(StandardError, 'service is down') }
      it 'returns 500' do
        subject.set_profile_image('123', 'url').should eq 500
      end
    end
  end
end
