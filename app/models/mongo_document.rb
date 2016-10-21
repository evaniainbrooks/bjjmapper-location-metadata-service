module MongoDocument
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def find(connection, conditions)
      model_attrs = connection[self.const_get(:COLLECTION_NAME)].find_one(conditions)
      return self.new(model_attrs)
    end

    def find_all(connection, conditions)
      puts "Searching for #{conditions} in #{self.const_get(:COLLECTION_NAME)}"

      models_attrs = connection[self.const_get(:COLLECTION_NAME)].find(conditions)
      return models_attrs.map { |model_attrs| self.new(model_attrs) }
    end
  end

  def initialize(attributes)
    attributes = attributes.instance_variables.inject({}) do |hash, k|
      key = k[1..-1]
      hash[key] = attributes.instance_variable_get(k); hash
    end unless attributes.is_a?(Hash)

    attributes.each_pair do |k, v|
      self.send("#{k}=", v) if self.respond_to?("#{k}=")
    end
  end

  def save(connection)
    if !self._id
      self.send(:insert, connection)
    else
      self.send(:update, connection)
    end
  end

  private

  def insert(connection)
    create_params = self.instance_variables.inject({}) do |hash, k|
      key = k[1..-1]
      hash[key] = instance_variable_get(k) unless key.start_with?('_')
      hash
    end

    connection[self.class.const_get(:COLLECTION_NAME)].insert(create_params)
  end
end
