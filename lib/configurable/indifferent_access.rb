module Configurable
  
  # Implements AGET and ASET methods that symbolize string keys, in effect 
  # producing indifferent access.  IndifferentAccess is intended to extend
  # a Hash.
  #
  # Note that the indifference produced by this module is very thin indeed.
  # Strings may still be used as keys through store/fetch, and
  # existing string keys are not changed in any way.  Nonetheless,
  # these methods are sufficient for Configurable and DelegateHash.
  module IndifferentAccess
    
    # Symbolizes string keys and calls super.
    def [](key)
      super(convert(key))
    end
    
    # Symbolizes string keys and calls super.
    def []=(key, value)
      super(convert(key), value)
    end
  
    private
    
    # a helper to convert strings to symbols
    def convert(key) # :nodoc:
      key.kind_of?(String) ? key.to_sym : key
    end
  end
end

module Configurable
  module IndifferentAccessPatch
    def []=(key, value)
      @key_order << key unless @key_order.include?(key)
      super
    end
  
    def each_pair
      keys.sort_by do |key|
        @key_order.index(key)
      end.each do |key|
        yield(key, fetch(key))
      end
    end
  end
  
  module IndifferentAccess
    include IndifferentAccessPatch
    
    def self.extended(base)
      base.instance_variable_set(:@key_order, [])
    end
  end
end if RUBY_VERSION < '1.9'