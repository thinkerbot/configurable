module Configurable
  
  # Implements AGET and ASET methods that symbolize string keys, in effect 
  # producing indifferent access.  IndifferentAccess is intended to extend
  # a Hash.
  #
  # Note that the indifference produced by this module is very thin indeed.
  # Strings may still be used as keys through store/fetch, and
  # existing string keys are not changed in any way.  Nonetheless,
  # these methods are sufficient for Configurable and ConfigHash.
  module IndifferentAccess
    
    # Symbolizes string keys and calls super.
    def [](key)
      super(convert(key))
    end
    
    # Symbolizes string keys and calls super.
    def []=(key, value)
      super(convert(key), value)
    end
    
    # Ensures duplicates use indifferent access.
    def dup
      super().extend IndifferentAccess
    end
    
    private
    
    # a helper to convert strings to symbols
    def convert(key) # :nodoc:
      key.kind_of?(String) ? key.to_sym : key
    end
  end
end