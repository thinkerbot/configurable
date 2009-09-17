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
  #   dhash = DelegateHash.new.bind(sample)
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
  
    # Initializes a new DelegateHash.  Note that initialize simply sets the
    # receiver, it does NOT map stored values the same way bind does.  This
    # allows quick, implicit binding when the store is set up beforehand.
    #
    # For more standard binding use: DelegateHash.new.bind(receiver)
    def initialize(store={}, receiver=nil)
      @store = store
      @receiver = receiver
    end

    # A hash of (key, Delegate) pairs identifying which keys to delegate to the
    # receiver. 
    #
    # Note that this is an inefficent method to call.
    def delegates
      receiver ? receiver.class.configurations : {}
    end

    # Binds self to the specified receiver.  Delegate values are removed from
    # store and sent to their writer on receiver.  If the store has no value
    # for a delegate key, the delegate default value will be used.
    def bind(receiver, rebind=false)
      raise ArgumentError, "receiver cannot be nil" if receiver == nil
      
      if bound? && !rebind
        if @receiver == receiver
          return(self)
        else
          raise ArgumentError, "already bound to: #{@receiver}"
        end
      end
      
      @receiver = receiver
      map(store)
      self
    end

    # Returns true if self is bound to a receiver
    def bound?
      receiver != nil
    end

    # Unbinds self from the specified receiver.  Delegate values
    # are stored in store.  Returns the unbound receiver.
    def unbind
      unmap(store)
      @receiver = nil
      self
    end

    # Retrieves the value corresponding to the key.  When bound, delegates pull
    # values from the receiver using the delegate.reader method; otherwise the
    # value in store will be returned.  When unbound, if the store has no value
    # for a delegate, the delgate default value will be returned.
    def [](key)
      if delegate = delegates[key]
        delegate.get(receiver)
      else
        store[key]
      end
    end

    # Stores a value for the key.  When bound, delegates set the value in the
    # receiver using the delegate.writer method; otherwise values are stored in
    # store.
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
      if bound?
        (delegates.keys | another.keys).each do |key|
          self[key] = another[key] if another.has_key?(key)
        end
      else
        # optimization for the common case of an 
        # unbound merge of another hash
        store.merge!(another.to_hash)
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
    
    # Ensures duplicates are unbound and store the same values as the original.
    def initialize_copy(orig)
      super
      
      @receiver = nil
      @store = @store.dup
      orig.unmap(@store) if orig.bound?
    end
    
    protected
    
    # helper to map delegate values from source to the receiver
    def map(source) # :nodoc:
      
      # optimization to prevent regeneration of delegates
      # for the duration of this method
      delegates = self.delegates
      
      source_values = {}
      source.each_key do |key|
        if delegate = delegates[key]
          if source_values.has_key?(delegate)
            key = delegates.keys.find {|k| delegates[k] == delegate }
            raise "multiple values mapped to #{key.inspect}"
          end
          
          source_values[delegate] = source.delete(key)
        end
      end
      
      delegates.each_pair do |key, delegate|
        # map the override value or the delegate default (if allowed)
        # this ensures each config is initialized to a value unless
        # manual initialization is specified
        if source_values.has_key?(delegate)
          delegate.set(receiver, source_values[delegate])
        else
          delegate.init(receiver)
        end
      end
    end
    
    # helper to unmap delegates from the receiver to a target hash
    def unmap(target) # :nodoc:
      delegates.each_pair do |key, delegate|
        target[key] = delegate.get(receiver)
      end
    end
  end
end