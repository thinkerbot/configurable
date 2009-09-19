require 'configurable/delegate'

module Configurable
  
  # DelegateHash delegates get and set operations to instance methods on a receiver.  
  #
  #   class Sample
  #     include Configurable
  #     config :key
  #   end
  #
  #   sample = Sample.new
  #   dhash = DelegateHash.new(sample)
  #
  #   sample.key = 'value'
  #   dhash[:key]                # => 'value'
  #
  #   dhash[:key] = 'another'
  #   sample.key                # => 'another'
  #
  # Non-delegate keys are sent to an underlying data store:
  #
  #   dhash[:not_delegated] = 'value'
  #   dhash[:not_delegated]      # => 'value'
  #
  #   dhash.store                # => {:not_delegated => 'value'}
  #   dhash.to_hash              # => {:key => 'another', :not_delegated => 'value'}
  #
  # ==== IndifferentAccess
  #
  # The delegates hash maps keys to Delegate objects.  In cases where multiple
  # keys need to map to the same delegate (for example when you want indifferent
  # access for strings and symbols), simply extend the delegate hash so that the
  # AGET ([]) method returns the correct delegate in all cases.
  #
  class DelegateHash

    # The bound receiver
    attr_reader :receiver

    # The underlying data store
    attr_reader :store
  
    # Initializes a new DelegateHash.  Initialize normally imports values from
    # store to ensure it doesn't contain entries that could be stored on the
    # receiver.  
    # 
    # Setting import_store to false allows quick initialization but can result
    # in inconsistencies where the store and receiver both have values for a
    # given key.
    def initialize(receiver, store={}, import_store=true)
      @receiver = receiver
      @store = store
      
      import(store) if import_store
    end
    
    # A hash of (key, Delegate) pairs identifying which keys to delegate to the
    # receiver. 
    #
    # Note that this is an inefficent method to call.
    def delegates
      receiver.class.configurations
    end
    
    # Imports stored values that can be mapped to the receiver.  The values
    # are removed from store in the process.  Returns self.
    #
    # Note import is primarily used to ensure a consistent state for self.
    # This should always work to correct inconsistency:
    #
    #   dhash.import(dhash.store)
    #
    def import(store)
      
      # ensure delegates are only calculated once, as an optimization
      delegate = self.delegates
      
      store.keys.each do |key|
        next unless delegate = delegates[key]
        delegate.set(receiver, store.delete(key))
      end
      
      self
    end
    
    # Returns true if the store has entries that could be stored on the
    # receiver.
    def inconsistent?
      store.keys.any? {|key| delegates[key] }
    end
    
    # Retrieves the value for the key, either from the receiver or the store.
    def [](key)
      if delegate = delegates[key]
        delegate.get(receiver)
      else
        store[key]
      end
    end

    # Stores a value for the key, either on the receiver or in the store.
    def []=(key, value)
      if delegate = delegates[key]
        delegate.set(receiver, value)
      else
        store[key] = value
      end
    end
    
    # Returns the union of delegate and store keys.
    def keys
      delegates.keys | store.keys
    end

    # True if the key is an assigned delegate or store key.
    def has_key?(key)
      delegates.has_key?(key) || store.has_key?(key) 
    end
    
    # Merges another with self.
    def merge!(another)
      (delegates.keys | another.keys).each do |key|
        self[key] = another[key] if another.has_key?(key)
      end
    end
    
    # Calls block once for each key-value pair stored in self.
    def each_pair # :yields: key, value
      keys.each {|key| yield(key, self[key]) }
    end

    # Equal if the to_hash values of self and another are equal.
    def ==(another)
      another.respond_to?(:to_hash) && to_hash == another.to_hash
    end

    # Returns self as a hash.  Any DelegateHash values are recursively
    # hashified, to account for nesting.
    def to_hash(scrub=false, &block)
      hash = {}
      each_pair do |key, value|
        if value.kind_of?(DelegateHash)
          value = value.to_hash(scrub, &block)
        end
        
        if scrub
          delegate = delegates[key]
          next if delegate && delegate.default == value
        end
        
        if block_given?
          yield(hash, key, value)
        else
          hash[key] = value
        end
      end
      hash
    end

    # Overrides default inspect to show the to_hash values.
    def inspect
      "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
    end
  end
end