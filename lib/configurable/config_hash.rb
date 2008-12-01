require 'configurable/config'

module Configurable
  
  # ConfigHash delegates get and set operations to instance methods on a receiver.  
  #
  #   class Sample
  #     attr_accessor :key
  #   end
  #   sample = Sample.new
  #
  #   dhash = ConfigHash.new
  #   dhash.delegates[:key] = Config.new(:key)
  #   dhash.bind(sample)
  #
  #   sample.key = 'value'
  #   dhash[:key]                # => 'value'
  #
  #   dhash[:key] = 'another'
  #   sample.key                 # => 'another'
  #
  # Non-delegate keys are sent to an underlying data store:
  #
  #   dhash[:not_delegated] = 'value'
  #   dhash[:not_delegated]      # => 'value'
  #
  #   dhash.store                # => {:not_delegated => 'value'}
  #   dhash.to_hash              # => {:key => 'another', :not_delegated => 'value'}
  #
  class ConfigHash
  
    # The bound receiver
    attr_reader :receiver
  
    # The underlying data store for non-delegate keys
    attr_reader :store
  
    # A hash of (key, Config) pairs identifying which
    # keys to delegate to the receiver
    attr_reader :delegates
    
    # Initializes a new ConfigHash.  Note that initialize simply sets the
    # receiver, it does NOT map stored values the same way bind does.
    # This allows quick, implicit binding where the bound store is set
    # up beforehand.
    #
    # For more standard binding use: ConfigHash.new.bind(receiver)
    def initialize(delegates={}, store={}, receiver=nil)
      @receiver = nil
      @store = store
      @delegates = delegates
      @receiver = receiver
    end
  
    # Binds self to the specified receiver.  Mapped keys are
    # removed from store and sent to their writer method on 
    # receiver.
    def bind(receiver)
      raise ArgumentError, "receiver cannot be nil" if receiver == nil
      raise ArgumentError, "already bound to: #{@receiver}" if bound? && @receiver != receiver
          
      delegates.each_pair do |key, delegate|
        if delegate.writer && store.has_key?(key)
          receiver.send(delegate.writer, store.delete(key))
        end
      end
      @receiver = receiver
    
      self
    end
  
    # Returns true if self is bound to a receiver
    def bound?
      receiver != nil
    end
  
    # Unbinds self from the specified receiver.  Mapped values
    # are stored in store.  Returns the unbound receiver.
    def unbind
      each_delegate do |key, delegate|
        store[key] = receiver.send(delegate.reader) if delegate.reader
      end
      current_receiver = receiver
      @receiver = nil
    
      current_receiver
    end
  
    # Retrieves the value corresponding to the key. If bound? 
    # and the key is a delegates key, then the value is
    # obtained from the delegate.reader method on the receiver.
    def [](key)
      case 
      when bound? && delegate = delegates[key]
        delegate.reader ? receiver.send(delegate.reader) : store[key]
      else store[key]
      end
    end
  
    # Associates the value the key.  If bound? and the key
    # is a delegates key, then the value will be forwarded
    # to the delegate.writer method on the receiver.
    def []=(key, value)
      case 
      when bound? && delegate = delegates[key]
        delegate.writer ? receiver.send(delegate.writer, value) : store[key] = value
      else store[key] = value
      end
    end
  
    # True if the key is assigned in self.
    def has_key?(key)
      (bound? && delegates.has_key?(key)) || store.has_key?(key) 
    end
  
    # Calls block once for each key-value pair stored in self.
    def each_pair # :yields: key, value
      each_delegate do |key, delegate|
        yield(key, receiver.send(delegate.reader)) if delegate.reader
      end if bound?
    
      store.each_pair do |key, value|
        yield(key, value)
      end
    end
  
    # Updates self to ensure that each delegates key
    # has a value in self; the delegate.default value is
    # set if a value does not already exist.
    #
    # Returns self.
    def update
      each_delegate do |key, delegate|
        self[key] ||= delegate.default
      end
      self
    end
  
    # Duplicates self, returning an unbound ConfigHash.
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
      each_delegate do |key, delegate|
        hash[key] = self[key]
      end if bound?
      hash
    end
  
    # Overrides default inspect to show the to_hash values.
    def inspect
      "#<#{self.class}:#{object_id} to_hash=#{to_hash.inspect}>"
    end
    
    private
    
    def each_delegate
      delegates.each_pair do |key, delegate|
        yield(key, delegate) if key == delegate.key
      end
    end
  end
end