# spec/spec_helper.rb
require 'rack/test'
require 'rspec'
require 'dotenv'
require 'factory_girl'

Dotenv.load

ENV['RACK_ENV'] = 'test'

require File.expand_path '../../application.rb', __FILE__

module RSpecMixin
  include Rack::Test::Methods
  def app() LocationFetchService::Application end
end

# For RSpec 2.x and 3.x
RSpec.configure do |c|
  c.expect_with(:rspec) { |o| o.syntax = :should }
  c.include RSpecMixin
  c.order = "random"
  c.include FactoryGirl::Syntax::Methods

  c.before(:suite) do
    FactoryGirl.definition_file_paths = %w(locationfetchsvc/spec/factories spec/factories)
    FactoryGirl.find_definitions
  end
end
