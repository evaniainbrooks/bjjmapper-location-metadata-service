require File.expand_path '../../../spec_helper.rb', __FILE__

describe 'ReviewsResponse' do
  describe '#respond' do
    def as_json(params)
      { as_json: params }
    end

    let(:rating1) { 5.0 }
    let(:rating2) { 4.0 }
    let(:listings) { { :google => double(rating: rating1), :yelp => double(rating: rating2) } }
    let(:expected_rating) { (rating1 + rating2) / 2.0 }
    
    let(:google_review) { double(as_json(key: 'google1')) }
    let(:yelp_review) { double(as_json(key: 'yelp1')) }
    let(:reviews) { { :google => [google_review], :yelp => [yelp_review] } }
    context 'with compare address' do
      let(:result) { Responses::ReviewsResponse.respond(listings, reviews) }
      
      it 'returns a json blob' do
        JSON.parse(result).should_not be_nil
      end

      it 'calculates the rating total' do
        JSON.parse(result)['rating'].should eq expected_rating
      end

      it 'returns all of the reviews' do
        JSON.parse(result)['reviews'].count.should eq 2
      end
    end
  end
end
