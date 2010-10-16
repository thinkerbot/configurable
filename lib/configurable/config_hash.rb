module Configurable
  
  # ConfigHash acts like a hash that maps get and set operations as specified
  # in by a receiver's class configurations. Non-configuration keys are sent
  # to an underlying data store.
  class ConfigHash
    # A frozen empty hash returned by configs for unbound config hashes.
    EMPTY_HASH =  {}.freeze
    
    # The bound receiver
    attr_reader :receiver
    
    # The underlying data store; setting values in store directly can result
    # in an inconsistent state.  Use []= instead.
    attr_reader :store
   
    # Initializes a new ConfigHash.
    def initialize(store={}, receiver=nil)
      @store = store
      @receiver = receiver
    end
    
    # Binds the configs in store to the receiver by setting each on the
    # receiver (via config.set).  Bound configs are removed from store.
    #
    # Unbinds self from the current receiver, if needed.
    def bind(receiver)
      unbind if bound?
      
      @receiver = receiver
      configs.each_pair do |key, config|
        value = store.has_key?(key) ? store.delete(key) : config.default
        config.set(receiver, value)
      end
      
      self
    end
    
    # Unbinds the configs set on receiver by getting each value (via
    # config.get) and setting the result into store. Does nothing if no
    # receiver is set.
    def unbind
      if bound?
        configs.each_pair do |key, config|
          store[key] = config.get(receiver)
        end
        @receiver = nil
      end
      self
    end
    
    # Returns true if bound to a receiver.
    def bound?
      @receiver ? true : false
    end
    
    # Returns the class configs for the bound receiver, or an empty hash if
    # unbound (specifically EMPTY_HASH).
    def configs
      # Caching here is not necessary or preferred as configurations are
      # cached on the class (which allows late inclusion of configurable
      # modules to work properly).
      bound? ? receiver.class.configs : EMPTY_HASH
    end
    
    # Returns true if bound to a receiver and no configs values are set in
    # store (ie all config values are stored on the receiver).
    def consistent?
      bound? && (store.keys & configs.keys).empty?
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
      configs.keys | store.keys
    end
    
    # True if the key is a key in configs or store.
    def has_key?(key)
      configs.has_key?(key) || store.has_key?(key) 
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
    def to_hash
      hash = {}
      each_pair do |key, value|
        if value.kind_of?(ConfigHash)
          value = value.to_hash
        end
        
        hash[key] = value
      end
      hash
    end
    
    # Returns self exported as a hash of raw configs (ie name keys and uncast
    # values).
    def export
      configs.export(to_hash)
    end
    
    # Imports a hash of raw configs (ie name keys and uncast values) and
    # merges the result with self.
    def import(another)
      merge! configs.import(another)
    end
    
    # Returns an inspection string.
    def inspect
      "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
    end
  end
end