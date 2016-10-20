class BaseModel
  def self.find(connection, conditions)
    model_attrs = connection[self.class.const_get(:COLLECTION_NAME)].find_one(conditions)
    return @_subclass.new(model_attrs)
  end

  def self.inherited(subclass)
    @_subclass = subclass
  end

  def initialize(obj)
    attributes = obj.instance_variables.inject({}) do |hash, key|
      hash[key] = obj.instance_variable_get(key); hash
    end
    
    attributes.each_pair do |k, v|
      key = k[1..-1]
      self.send("#{key}=", v) if self.respond_to?("#{key}=")
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
