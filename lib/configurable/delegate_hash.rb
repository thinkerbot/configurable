require 'configurable/delegate'

module Configurable
  
  # DelegateHash delegates get and set operations to instance methods on a receiver.  
  #
  #   class Sample
  #     attr_accessor :key
  #   end
  #   sample = Sample.new
  #
  #   dhash = DelegateHash.new
  #   dhash.delegates[:key] = Delegate.new(:key)
  #   dhash.bind(sample)
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

    # A hash of (key, Delegate) pairs identifying which
    # keys to delegate to the receiver
    attr_reader :delegates
  
    # Initializes a new DelegateHash.  Note that initialize simply sets the
    # receiver, it does NOT map stored values the same way bind does.  This
    # allows quick, implicit binding when the store is set up beforehand.
    #
    # For more standard binding use: DelegateHash.new.bind(receiver)
    def initialize(delegates={}, store={}, receiver=nil)
      @receiver = nil
      @store = store
      @delegates = delegates
      @receiver = receiver
    end

    # Binds self to the specified receiver.  Delegate values are removed from
    # store and sent to their writer method on receiver.  If the store has no
    # value for a delegate key, the delegate default value will be used.
    def bind(receiver)
      raise ArgumentError, "receiver cannot be nil" if receiver == nil
      raise ArgumentError, "already bound to: #{@receiver}" if bound? && @receiver != receiver
        
      delegates.each_pair do |key, delegate|
        if delegate.writer
          value = store.has_key?(key) ? store.delete(key) : delegate.default
          receiver.send(delegate.writer, value)
        end
      end
      @receiver = receiver
  
      self
    end

    # Returns true if self is bound to a receiver
    def bound?
      receiver != nil
    end

    # Unbinds self from the specified receiver.  Delegate values
    # are stored in store.  Returns the unbound receiver.
    def unbind
      delegates.each_pair do |key, delegate|
        store[key] = receiver.send(delegate.reader) if delegate.reader
      end
      current_receiver = receiver
      @receiver = nil
  
      current_receiver
    end

    # Retrieves the value corresponding to the key.  When bound, delegates with
    # readers pull values from the receiver; otherwise the value in store will
    # be returned.  When unbound, if the store has no value for a delegate, the
    # delgate default value will be returned.
    def [](key)
      return store[key] unless delegate = delegates[key]
      
      case
      when bound? && delegate.reader
        receiver.send(delegate.reader)
      when store.has_key?(key)
        store[key]
      else
        delegate.default
      end
    end

    # Stores a value for the key.  When bound, delegates with writers send the
    # value to the receiver; otherwise values are stored in store.
    def []=(key, value)
      if bound? && delegate = delegates[key]
        if delegate.writer
          receiver.send(delegate.writer, value)
          return
        end
      end
      
      store[key] = value
    end
    
    # Returns the union of delegate and store keys.
    def keys
      delegates.keys | store.keys
    end

    # True if the key is assigned in self.
    def has_key?(key)
      delegates.has_key?(key) || store.has_key?(key) 
    end

    # Calls block once for each key-value pair stored in self.
    def each_pair # :yields: key, value
      keys.each {|key| yield(key, self[key]) }
    end

    # Duplicates self, returning an unbound DelegateHash.
    def dup
      duplicate = super()
      duplicate.instance_variable_set(:@receiver, nil)
      duplicate.instance_variable_set(:@store, @store.dup)
      duplicate
    end

    # Equal if the to_hash values of self and another are equal.
    def ==(another)
      another.respond_to?(:to_hash) && to_hash == another.to_hash
    end

    # Returns self as a hash. 
    def to_hash
      hash = store.dup
      delegates.keys.each do |key|
        value = self[key]
        hash[key] = value.kind_of?(DelegateHash) ? value.to_hash : value
      end
      hash
    end

    # Overrides default inspect to show the to_hash values.
    def inspect
      "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
    end
  end
end