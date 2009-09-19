require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/delegate_hash'

class DelegateHashTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  
  # a dummy receiver
  class Receiver
    class << self
      attr_accessor :configurations
    end
    
    attr_accessor :key
    
    def initialize
      @key = nil
    end
  end
  
  # a receiver to log the order in which values are sent to key
  class OrderedReceiver
    class << self
      attr_accessor :configurations
    end
    
    attr_reader :order
    
    def initialize
      @order = []
    end
    
    def key=(value)
      order << value
    end
  end
  
  # a hash that iterates each_pair in a predefined order
  class OrderedHash < Hash
    attr_reader :keys
    
    def initialize(*keys)
      @keys = keys
    end
    
    def each_pair
      @keys.each {|key| yield(key, self[key])}
    end
  end
  
  attr_reader :dhash
  
  def setup
    Receiver.configurations = {:key => Delegate.new(:key)}
    @dhash = DelegateHash.new(Receiver.new)
  end
  
  #
  # documentation test
  #
  
  # class Sample
  #   include Configurable
  #   config :key
  # end
  # 
  # def test_documentation
  #   sample = Sample.new
  #   dhash = DelegateHash.new(sample)
  # 
  #   sample.key = 'value'
  #   assert_equal 'value', dhash[:key]
  # 
  #   dhash[:key] = 'another'
  #   assert_equal 'another', sample.key
  # 
  #   dhash[:not_delegated] = 'value'
  #   assert_equal 'value', dhash[:not_delegated]
  # 
  #   assert_equal({:not_delegated => 'value'}, dhash.store)
  #   assert_equal({:key => 'another', :not_delegated => 'value'}, dhash.to_hash)
  # end
  
  #
  # initialization test
  #
  
  def test_initialize
    receiver = Receiver.new
    store = {}
    dhash = DelegateHash.new(receiver, store)
    
    assert_equal(receiver, dhash.receiver)
    assert_equal(store, dhash.store)
  end
  
  def test_initialize_imports_store_to_receiver
    receiver = Receiver.new
    receiver.key = "existing value"
    
    dhash = DelegateHash.new(receiver, {:key => 'new value'})
    assert_equal({}, dhash.store)
    assert_equal "new value", receiver.key
  end
  
  def test_initialize_does_not_import_store_to_receiver_if_specified
    receiver = Receiver.new
    receiver.key = "existing value"
    
    dhash = DelegateHash.new(receiver, {:key => 'new value'}, false)
    assert_equal({:key => 'new value'}, dhash.store)
    assert_equal "existing value", receiver.key
  end
  
  #
  # inconsistent? test
  #
  
  def test_inconsistent_returns_true_if_the_store_has_delegateable_values
    assert_equal false, dhash.inconsistent?
    
    dhash.store[:key] = 'value'
    assert_equal true, dhash.inconsistent?
    
    dhash.store.delete(:key)
    assert_equal false, dhash.inconsistent?
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_value_stored_on_receiver_for_delegate_key
    dhash.store[:key] = 'dhash value'
    
    dhash.receiver.key = nil
    assert_equal nil, dhash[:key]
    
    dhash.receiver.key = "receiver value"
    assert_equal 'receiver value', dhash[:key]
  end
  
  def test_AGET_returns_store_value_for_non_delegate_key
    dhash.store[:alt] = 'dhash value'
    assert_equal 'dhash value', dhash[:alt]
  end
  
  #
  # ASET test
  #
  
  def test_ASET_stores_value_on_receiver_for_delegate_key
    assert_equal nil, dhash.receiver.key
    dhash[:key] = 'value'
    assert_equal "value", dhash.receiver.key
  end
  
  def test_ASET_stores_value_in_store_for_non_delegate_key
    assert_equal nil, dhash.receiver.key
    assert_equal({}, dhash.store)
    
    dhash[:alt] = 'value'
    
    assert_equal nil, dhash.receiver.key
    assert_equal({:alt => 'value'}, dhash.store)
  end
  
  #
  # keys test
  #
  
  def test_keys_returns_union_of_delegate_keys_and_store_keys
    dhash.store[:alt] = nil
    
    assert_equal [:key], dhash.delegates.keys
    assert_equal [:alt], dhash.store.keys
    assert_equal [:key, :alt], dhash.keys
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_is_a_delegate_key_or_a_store_key
    dhash.store[:alt] = 'value'
    
    assert dhash.has_key?(:key)
    assert dhash.has_key?(:alt)
    assert !dhash.has_key?(:not_a_key)
  end
  
  #
  # merge! test
  #
  
  def test_merge_merges_another_with_self
    dhash[:key] = 'value'
    dhash[:a] = 'a'
    
    assert_equal 'value', dhash.receiver.key
    assert_equal({:a => 'a'}, dhash.store)
    
    dhash.merge!(:key => 'VALUE', :b => 'B')
    assert_equal 'VALUE', dhash.receiver.key
    assert_equal({:a => 'a', :b => 'B'}, dhash.store)
  end
  
  def test_merge_can_merge_another_DelegateHash
    dhash[:key] = 'value'
    dhash[:a] = 'a'
    assert_equal 'value', dhash.receiver.key
    assert_equal({:a => 'a'}, dhash.store)
    
    another = DelegateHash.new(Receiver.new, :key => 'VALUE', :b => 'B')
    assert_equal 'VALUE', another.receiver.key
    assert_equal({:b => 'B'}, another.store)
    
    dhash.merge!(another)
    assert_equal 'VALUE', dhash.receiver.key
    assert_equal({:a => 'a', :b => 'B'}, dhash.store)
  end
  
  def test_merge_sets_delegates_in_order
    letters = [:a, :b, :c, :d, :e, :f, :g, :h]
    delegates = OrderedHash.new(*letters)
    letters.each {|letter| delegates[letter] = Delegate.new(:key, :key=, letter.to_s) }
    
    OrderedReceiver.configurations = delegates
    dhash = DelegateHash.new(OrderedReceiver.new)
  
    dhash.merge!({:a => 'A', :g => 'G', :c => 'C', :h => 'H', :b => 'B'})
    assert_equal ['A', 'B', 'C', 'G', 'H'], dhash.receiver.order
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_yields_each_key_value_pair_stored_in_self
    dhash[:key] = 'value'
    dhash[:alt] = 'VALUE'
    
    results = {}
    dhash.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :alt => 'VALUE'}, results)
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_hash_merging_receiver_and_store_entries
    dhash.store[:alt] = 'VALUE'
    dhash.receiver.key = 'value'
    
    assert_equal({:key => 'value', :alt => 'VALUE'}, dhash.to_hash)
  end
  
  def test_to_hash_recursively_hashifies_DelegateHash_values
    a = DelegateHash.new(Receiver.new, :a => 'value')
    b = DelegateHash.new(Receiver.new, :b => a)
    c = DelegateHash.new(Receiver.new, :c => b)
    
    assert_equal({
      :key => nil,
      :c => {
        :key => nil,
        :b => {
          :key => nil,
          :a => 'value'
        }
      }
    }, c.to_hash)
  end
  
  def test_to_hash_accepts_a_block_to_transform_keys_and_values
    a = DelegateHash.new(Receiver.new, :a => 'value')
    b = DelegateHash.new(Receiver.new, :b => a)
    c = DelegateHash.new(Receiver.new, :c => b)
    
    result = c.to_hash do |hash, key, value|
      hash[key.to_s] = value.kind_of?(String) ? value.upcase : value
    end
    
    assert_equal({
      'key' => nil,
      'c' => {
        'key' => nil,
        'b' => {
          'key' => nil,
          'a' => 'VALUE'
        }
      }
    }, result)
  end
  
  def test_to_hash_scrubs_delegates_set_to_default_value_if_specified
    dhash.store[:alt] = nil
    dhash.receiver.key = nil

    assert_equal({:alt => nil, :key => nil}, dhash.to_hash)
    assert_equal({:alt => nil}, dhash.to_hash(true))
    
    dhash.receiver.key = :value
    assert_equal({:alt => nil, :key => :value}, dhash.to_hash(true))
  end
  
  def test_to_hash_scrubs_delgates_recursively
    a = DelegateHash.new(Receiver.new, :a => 'value')
    b = DelegateHash.new(Receiver.new, :b => a)
    c = DelegateHash.new(Receiver.new, :c => b)
    
    assert_equal({
      :c => {:b => {:a => 'value'}}
    }, c.to_hash(true))
  end
  
  #
  # == test
  #
  
  def test_equals_compares_to_hash_values
    dhash = DelegateHash.new(Receiver.new)
    assert dhash == {:key => nil}
    
    dhash[:key] = 'value'
    dhash[:alt] = 'VALUE'
    assert dhash == {:key => 'value', :alt => 'VALUE'}
    
    another = DelegateHash.new(Receiver.new, {:key => 'value', :alt => 'VALUE'})
    assert dhash == another
  end
end