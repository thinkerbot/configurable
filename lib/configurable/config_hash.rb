require 'configurable/config'

module Configurable
  
  # ConfigHash acts like a hash that maps get and set operations as specified
  # in by a receiver's class configurations. Non-configuration keys are sent
  # to an underlying data store.
  class ConfigHash
    
    # The bound receiver
    attr_reader :receiver
    
    # The underlying data store; setting values in store directly
    # can result in an inconsistent state.  Use []= instead.
    attr_reader :store
    
    # Initializes a new ConfigHash.  Initialize normally imports values from
    # store to ensure it doesn't contain entries that could be stored on the
    # receiver.  Set import_store to false for quicker initialization when
    # you know the store is already in a consistent state.
    def initialize(receiver, store={}, import_store=true)
      @receiver = receiver
      @store = store
      
      import(store) if import_store
    end
    
    # Returns receiver.class.configurations.
    def configs
      receiver.class.configurations
    end
    
    # Imports stored values that can be mapped to the receiver.  The values
    # are removed from store in the process.  Returns self.
    #
    # Primarily used to create a consistent state for self (see above).
    def import(store)
      configs = self.configs
      store.keys.each do |key|
        if config = configs[key]
          config.set(receiver, store.delete(key))
        end
      end
      
      self
    end
    
    # Returns true if the store has entries that can be stored on the
    # receiver. To avoid inconsistency, don't manually add values to the
    # store. To repair inconsistency, import the current store to self.
    #
    #   config_hash.import(config_hash.store)
    #
    def inconsistent?
      configs = self.configs
      store.keys.any? {|key| configs[key] }
    end
    
    # Retrieves the value for the key, either from the receiver or the store.
    def [](key)
      if config = configs[key]
        config.get(receiver)
      else
        store[key]
      end
    end

    # Stores a value for the key, either on the receiver or in the store.
    def []=(key, value)
      if config = configs[key]
        config.set(receiver, value)
      else
        store[key] = value
      end
    end
    
    # Returns the union of configs and store keys.
    def keys
      config_keys = []
      configs.each_pair {|key, config| config_keys << key if config }
      config_keys | store.keys
    end
    
    # True if the key is a key in configs or store.
    def has_key?(key)
      configs[key] != nil || store.has_key?(key) 
    end
    
    # Merges another with self.
    def merge!(another)
      configs = self.configs
      another.each_pair do |key, value|
        if config = configs[key]
          config.set(receiver, value)
        else
          store[key] = value
        end
      end
    end
    
    # Calls block once for each key-value pair stored in self.
    def each_pair # :yields: key, value
      configs.each_pair do |key, config|
        yield(key, config.get(receiver))
      end
      
      store.each_pair do |key, value|
        yield(key, value)
      end
    end

    # Equal if the to_hash values of self and another are equal.
    def ==(another)
      another.respond_to?(:to_hash) && to_hash == another.to_hash
    end

    # Returns self as a hash.  Any ConfigHash values are recursively
    # hashified, to account for nesting.
    def to_hash(scrub=false, &block)
      hash = {}
      each_pair do |key, value|
        if value.kind_of?(ConfigHash)
          value = value.to_hash(scrub, &block)
        end
        
        if scrub
          config = configs[key]
          next if config && config.default == value
        end
        
        if block_given?
          yield(hash, key, value)
        else
          hash[key] = value
        end
      end
      hash
    end

    # Returns an inspection string.
    def inspect
      "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
    end
  end
end