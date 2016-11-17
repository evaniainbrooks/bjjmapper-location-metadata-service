module MongoDocument
  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def find(connection, conditions)
      model_attrs = connection[self.const_get(:COLLECTION_NAME)].find_one(conditions)
      
      return nil if model_attrs.nil?
      return self.new(model_attrs)
    end

    def upsert(connection, conditions, attributes)
      connection[self.const_get(:COLLECTION_NAME)].update(conditions, {'$set' => attributes}, {:upsert => true})
    end

    def find_all(connection, conditions)
      models_attrs = connection[self.const_get(:COLLECTION_NAME)].find(conditions)
      
      return nil if models_attrs.nil?
      return models_attrs.map { |model_attrs| self.new(model_attrs) }
    end

    def update_all(connection, conditions, attributes)
      connection[self.const_get(:COLLECTION_NAME)].update_many(conditions, {'$set' => attributes})
    end
    
    def delete_all(connection, conditions)
      connection[self.const_get(:COLLECTION_NAME)].delete_many(conditions)
    end
  end

  def initialize(attributes = {})
    self.merge_attributes!(attributes)
  end

  def merge_attributes!(attributes)
    if !attributes.is_a?(Hash)
      attributes = self.class.const_get(:COLLECTION_FIELDS).inject({}) do |hash, k|
        hash[k] = attributes.send(k) if attributes.respond_to?(k)
        hash
      end
    end

    attributes.each_pair do |k, v|
      self.send("#{k}=", v) if self.respond_to?("#{k}=")
    end
  end

  def save(connection)
    if !self._id
      self.send(:insert, connection)
    else
      self.send(:update, connection, create_params)
    end
  end
    
  def upsert(connection, conditions)
    connection[self.class.const_get(:COLLECTION_NAME)].update(conditions, create_params, {:upsert => true})
  end

  private
  
  def update(connection, update_params)
    connection[self.class.const_get(:COLLECTION_NAME)].update({'_id' => self._id}, {'$set' => update_params})
  end

  def insert(connection)
    connection[self.class.const_get(:COLLECTION_NAME)].insert(create_params)
  end

  def create_params
    create_params = self.instance_variables.inject({}) do |hash, k|
      key = k[1..-1]
      hash[key] = instance_variable_get(k) unless key.start_with?('_')
      hash
    end
  end
end
