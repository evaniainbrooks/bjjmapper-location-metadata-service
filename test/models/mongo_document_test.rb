ENV['RACK_ENV'] = 'test'

require './app/models/mongo_document'

class SubjectClass
  COLLECTION_NAME = 'some_collection'

  include MongoDocument

  attr_accessor :first_name, :last_name
end

class MongoDocumentTest < Test::Unit::TestCase
  def test_initialize_with_hash
    subject = SubjectClass.new({first_name: 'Hello', last_name: 'World'})
    assert_equal subject.first_name, 'Hello'
    assert_equal subject.last_name, 'World'
  end

  def test_initialize_with_instance_vars
    subject = SubjectClass.new(Class.new { def initialize; @first_name = 'Hello'; end }.new)
    assert_equal subject.first_name, 'Hello'
  end

  def test_save_calls_insert
    expected_params = {first_name: 'Hello'}.freeze

    mongo_mock = mock('mongo')
    mongo_mock.expects(:insert).with(expected_params)

    connection_mock = mock('connection')
    connection_mock.expects(:[]).with(subject_class::COLLECTION_NAME).returns(mongo_mock)

    subject = SubjectClass.new(expected_params)
    subject.save
  end
end

