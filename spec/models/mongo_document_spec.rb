require File.expand_path '../../spec_helper.rb', __FILE__

describe MongoDocument do
  let(:test_class) do
    Class.new do
      COLLECTION_NAME ='test_collection'
      COLLECTION_FIELDS = [:_id, :test_field]
      include MongoDocument

      attr_accessor *COLLECTION_FIELDS
    end
  end
  let(:mongo) { double }
  let(:connection) do
    connection = {}
    connection[test_class.const_get(:COLLECTION_NAME)] = mongo
    connection
  end
  describe '#find' do
    let(:conditions) { { test_field: 123 } }
    before { mongo.should_receive(:find_one).with(conditions) }
    it 'calls find_one on the interface' do
      test_class.find(connection, conditions)
    end
  end
  describe '#find_all' do
    let(:conditions) { { test_field: 123 } }
    before { mongo.should_receive(:find).with(conditions) }
    it 'calls find on the interface' do
      test_class.find_all(connection, conditions)
    end
  end
  describe "#update_all" do
    let(:conditions) { { test_field: 123 } }
    before { mongo.should_receive(:update_many).with(conditions, "$set" => {}) }
    it 'calls update_many on the interface' do
      test_class.update_all(connection, conditions, {})
    end
  end
  describe "#delete_all" do
    let(:conditions) { { test_field: 123 } }
    before { mongo.should_receive(:delete_many).with(conditions) }
    it 'calls find on the interface' do
      test_class.delete_all(connection, conditions)
    end
  end
  describe '.save' do
    context 'when the _id field is set' do
      let(:subject) { test_class.new(test_field: 'meow', _id: 123) }
      before { mongo.should_receive(:update).with({'_id' => 123}, {'$set' => {'test_field' => 'meow'}}) }
      it 'calls update on the interface' do
        subject.save(connection)
      end
    end
    context 'when the _id field is not set' do
      let(:subject) { test_class.new(test_field: 'meow') }
      before { mongo.should_receive(:insert).with({'test_field' => 'meow'}) }
      it 'calls update on the interface' do
        subject.save(connection)
      end
    end
  end
  describe '.upsert' do
    let(:conditions) { { '_id' => 123  } } 
    let(:subject) { test_class.new(test_field: 'meow') }
    before { mongo.should_receive(:update).with(conditions, {'test_field' => 'meow'}, {upsert: true}) }
    it 'calls update(upsert: true) on the interface' do
      subject.upsert(connection, conditions)
    end
  end
  describe '.merge_attributes!' do
    let(:subject) { test_class.new }
    context 'with hash' do
      it 'merges the attributes' do
        subject.merge_attributes!({test_field: 123})
        subject.test_field.should eq 123
      end
    end
    context 'with object' do
      it 'merges the instance vars' do
        subject.merge_attributes!(double(test_field: 123))
        subject.test_field.should eq 123
      end
    end
  end
end