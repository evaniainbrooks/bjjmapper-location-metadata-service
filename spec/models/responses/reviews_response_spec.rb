require File.expand_path '../../../spec_helper.rb', __FILE__

describe 'Responses::ReviewsResponse' do
  describe '#respond' do
    def as_json(params)
      { as_json: params }
    end

    let(:google_review) { double(as_json(key: 'google1')) }
    let(:yelp_review) { double(as_json(key: 'yelp1')) }
    let(:reviews) { { :google => [google_review], :yelp => [yelp_review] } }
    context 'with compare address' do
      let(:result) { Responses::ReviewsResponse.respond(reviews) }
      
      it 'returns a json blob' do
        result.to_json.should_not be_nil
      end

      it 'returns all of the reviews' do
        result.count.should eq 2
      end
    end
  end
end
