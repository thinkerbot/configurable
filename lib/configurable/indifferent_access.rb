module Configurable
  module IndifferentAccess

    def [](key)
      super(convert(key))
    end
  
    def []=(key, value)
      super(convert(key), value)
    end
  
    private
  
    def convert(key)
      key.kind_of?(String) ? key.to_sym : key
    end
  end
end