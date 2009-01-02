require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/delegate_hash'

class DelegateHashTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  
  # a dummy receiver
  class Receiver
    attr_accessor :key
    
    def initialize
      @key = nil
    end
  end
  
  # a receiver to log the order in which values are sent to key
  class OrderedReceiver
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
  
  attr_reader :d, :r
  
  def setup
    @r = Receiver.new
    @d = DelegateHash.new({:key => Delegate.new(:key)})
  end
  
  #
  # documentation test
  #
  
  class Sample
    attr_accessor :key
  end
  
  def test_documentation
    sample = Sample.new
    
    dhash = DelegateHash.new
    dhash.delegates[:key] = Delegate.new(:key)
    dhash.bind(sample)
  
    sample.key = 'value'
    assert_equal 'value', dhash[:key]
  
    dhash[:key] = 'another'
    assert_equal 'another', sample.key
  
    dhash[:not_delegated] = 'value'
    assert_equal 'value', dhash[:not_delegated]
  
    assert_equal({:not_delegated => 'value'}, dhash.store)
    assert_equal({:key => 'another', :not_delegated => 'value'}, dhash.to_hash)
  end
  
  #
  # initialization test
  #
  
  def test_default_initialize
    d = DelegateHash.new
    assert_equal(nil, d.receiver)
    assert_equal({}, d.store)
    assert_equal({}, d.delegates)
  end
  
  def test_initialize_sets_receiver_without_mapping_store_or_delegate_default_values
    r = Receiver.new
    r.key = "existing value"
    
    d = DelegateHash.new({:key => Delegate.new(:key)}, {:key => 'value'}, r)
    
    assert d.bound?
    assert_equal({:key => 'value'}, d.store)
    assert_equal r, d.receiver
    assert_equal "existing value", r.key
  end
  
  #
  # bind test
  #
  
  def test_bind_sets_receiver
    d.bind(r)
    assert_equal r, d.receiver
  end
  
  def test_bind_delegates_stored_values_to_receiver
    d.store[:key] = 1
    d.store[:not_a_config] = 1
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, d.store)
    
    d.bind(r)
    
    assert_equal 1, r.key
    assert_equal({:not_a_config => 1}, d.store)
  end
  
  def test_bind_delegates_default_values_to_receiver_if_no_store_value_is_present
    d.delegates[:key].default = 1
    
    assert_nil r.key
    assert_equal({}, d.store)
    
    d.bind(r)
    assert_equal 1, r.key
  end
  
  def test_bind_does_not_delegate_values_to_delegates_without_a_writer
    d.delegates[:key].writer = nil
    d.delegates[:key].default = 1
    d.store[:key] = 1
    d.store[:not_a_config] = 1
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, d.store)
    
    d.bind(r)
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, d.store)
  end
  
  def test_bind_does_nothing_if_bound_again_to_the_current_receiver
    assert_nil r.key
    
    d.store[:key] = 1
    d.bind(r)
    assert_equal 1, r.key
    assert_equal({}, d.store)
    
    d.store[:key] = 2
    d.bind(r)
    assert_equal 1, r.key
    assert_equal({:key => 2}, d.store)
  end
  
  def test_bind_raises_error_for_nil_receiver
    e = assert_raises(ArgumentError) { d.bind(nil) }
    assert_equal "receiver cannot be nil", e.message
  end
  
  def test_bind_raises_error_if_already_bound
    d.bind(r)
    e = assert_raises(ArgumentError) { d.bind(Receiver.new) }
    assert_equal "already bound to: #{r}", e.message
  end
  
  def test_bind_returns_self
    assert_equal d, d.bind(r)
  end
  
  def test_bind_sets_delegates_in_order
    delegates = OrderedHash.new(:a, :b, :c)
    delegates[:a] = Delegate.new(:key, :key=, 'a')
    delegates[:b] = Delegate.new(:key, :key=, 'b')
    delegates[:c] = Delegate.new(:key, :key=, 'c')
    
    r = OrderedReceiver.new
    d = DelegateHash.new(delegates)
    d.bind(r)
    
    assert_equal ['a', 'b', 'c'], r.order
    
    r = OrderedReceiver.new
    d = DelegateHash.new(delegates, {:a => 'A', :c => 'C'})
    d.bind(r)
    
    assert_equal ['A', 'b', 'C'], r.order
  end
  
  #
  # bound? test
  #
  
  def test_bind_unbind_toggles_bound
    assert !d.bound?
    
    d.bind(r)
    assert d.bound?
    
    d.unbind
    assert !d.bound?
  end
  
  #
  # unbind test
  #
  
  def test_unbind_unsets_receiver
    d.bind(r)
    assert_equal r, d.receiver
    
    d.unbind
    assert_equal nil, d.receiver
  end
  
  def test_unbind_sets_store_with_receiver_values
    d.bind(r)
    
    r.key = 1
    assert_equal({}, d.store)
    
    d.unbind
    
    assert_equal 1, r.key
    assert_equal({:key => 1}, d.store)
  end
  
  def test_unbind_does_not_store_values_for_delegates_without_a_reader
    d.delegates[:key].reader = nil
    d.bind(r)
  
    r.key = 1
    assert_equal({}, d.store)
    
    d.unbind
    
    assert_equal 1, r.key
    assert_equal({}, d.store)
  end
   
  def test_unbind_returns_self
    d.bind(r)
    assert_equal d, d.unbind
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_store_value_if_not_bound
    assert !d.bound?
    
    assert_equal({}, d.store)
    assert_equal nil, d[:key]
    
    d.store[:key] = 'value'
    assert_equal 'value', d[:key]
  end
  
  def test_AGET_returns_mapped_method_on_receiver_if_bound_and_key_is_mapped
    d.bind(r)
  
    assert_equal nil, d[:key]
    r.key = "value"
    assert_equal "value", d[:key]
  end
  
  def test_AGET_returns_stored_value_if_bound_and_key_is_not_mapped
    d.bind(r)
     
    assert_equal nil, d[:unmapped]
    d.store[:unmapped] = "value"
    assert_equal "value", d[:unmapped]
  end
  
  def test_AGET_returns_stored_value_if_delegate_has_no_reader
    d.delegates[:key].reader = nil
    d.bind(r)
    
    assert_equal nil, d.store[:unmapped]
    d[:unmapped] = "value"
    assert_equal "value", d.store[:unmapped]
  end
  
  def test_AGET_sets_missing_default_values_for_delegates_in_store_if_unbound
    d.delegates[:key].default = "default"
    
    assert !d.bound?
    assert_equal nil, d.store[:key]
    assert_equal "default", d[:key]
    assert_equal "default", d.store[:key]
  end
  
  def test_AGET_does_not_regard_nil_values_as_missing
    d.delegates[:key].default = "default"
    d.store[:key] = nil
    
    assert !d.bound?
    assert_equal nil, d[:key]
    assert_equal nil, d.store[:key]
  end
  
  #
  # ASET test
  #
  
  def test_ASET_stores_value_in_store_if_not_bound
    assert !d.bound?
    assert_equal({}, d.store)
    d[:key] = 'value'
    assert_equal({:key => 'value'}, d.store)
  end
  
  def test_ASET_send_value_to_mapped_method_on_receiver_if_bound_and_key_is_mapped
    d.bind(r)
    
    assert_equal nil, r.key
    d[:key] = 'value'
    assert_equal "value", r.key
  end
  
  def test_ASET_stores_value_in_store_if_bound_and_key_is_not_mapped
    d.bind(r)
  
    assert_equal nil, d.store[:unmapped]
    d[:unmapped] = "value"
    assert_equal "value", d.store[:unmapped]
  end
  
  def test_ASET_stores_value_in_store_if_config_has_no_writer
    d.delegates[:key].writer = nil
    d.bind(r)
  
    assert_equal nil, d.store[:unmapped]
    d[:unmapped] = "value"
    assert_equal "value", d.store[:unmapped]
  end
  
  #
  # keys test
  #
  
  def test_keys_returns_union_of_delegates_and_store_keys
    d.store[:unmapped] = nil
    
    assert_equal [:key], d.delegates.keys
    assert_equal [:unmapped], d.store.keys
    assert_equal [:key, :unmapped], d.keys
    
    d.store[:key] = nil
    
    assert_equal [:key], d.delegates.keys
    assert_equal [:key, :unmapped], d.store.keys
    assert_equal [:key, :unmapped], d.keys
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_is_assigned_in_delegates_or_in_store
    d[:key] = 'value'
    d[:another] = 'value'
    
    assert_equal({:key => 'value', :another => 'value'}, d.store)
    assert d.has_key?(:key)
    assert d.has_key?(:another)
    assert !d.has_key?(:not_a_key)
    
    d.bind(r)
    
    assert_equal({:another => 'value'}, d.store)
    assert d.has_key?(:key)
    assert d.has_key?(:another)
    assert !d.has_key?(:not_a_key)
  end
  
  #
  # merge! test
  #
  
  def test_merge_merges_another_with_self
    d[:key] = 'a'
    d[:one] = 'A'
    assert_equal({:key => 'a', :one => 'A'}, d.to_hash)
    
    # unbound merge!
    d.merge!(:key => 'b', :one => 'B', :two => :B)
    assert_equal({:key => 'b', :one => 'B', :two => :B}, d.to_hash)
    
    # bound merge!
    d.bind(r)
    d.merge!(:key => 'c')
    assert_equal 'c', r.key
  end
  
  def test_merge_can_merge_another_DelegateHash
    d[:key] = 'a'
    d[:one] = 'A'
    assert_equal({:key => 'a', :one => 'A'}, d.to_hash)
    
    # unbound merge!
    r2 = Receiver.new
    d2 = DelegateHash.new({:key => Delegate.new(:key)})
    d2.bind(r2)
    d2[:key] = 'b'
    d2[:one] = 'B'
    d2[:two] = :B
    
    d.merge!(d2)
    assert_equal({:key => 'b', :one => 'B', :two => :B}, d.to_hash)
    
    # bound merge!
    d3 = DelegateHash.new({:key => Delegate.new(:key)})
    d3.bind(Receiver.new)
    d3[:key] = 'c'
    
    d.bind(r)
    d.merge!(d3)
    assert_equal 'c', r.key
  end
  
  def test_merge_sets_delegates_in_order
    letters = [:a, :b, :c, :d, :e, :f, :g, :h]
    delegates = OrderedHash.new(*letters)
    letters.each {|letter| delegates[letter] = Delegate.new(:key, :key=, letter.to_s) }

    r = OrderedReceiver.new
    d = DelegateHash.new(delegates, {}, r)

    d.merge!({:a => 'A', :g => 'G', :c => 'C', :h => 'H', :b => 'B'})
    assert_equal ['A', 'B', 'C', 'G', 'H'], r.order
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_yields_each_key_value_pair_stored_in_self
    d[:key] = 'value'
    d[:another] = 'value'
    
    results = {}
    d.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :another => 'value'}, results)
    
    d.bind(r)
    
    r.key = 'VALUE'
    results = {}
    d.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'VALUE', :another => 'value'}, results)
  end
  
  #
  # == test
  #
  
  def test_equals_compares_to_hash_values
    d = DelegateHash.new
    assert d == {}
    
    d[:one] = 'one'
    assert d == {:one => 'one'}
    
    d2 = DelegateHash.new({}, {:one => 'one'})
    assert d == d2
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_duplicate_store_when_unbound
    d.store[:one] = 'one'
    d.store[:key] = 'value'
    
    assert_equal({:one => 'one', :key => 'value'}, d.store)
    assert_equal({:one => 'one', :key => 'value'}, d.to_hash)
    assert d.store.object_id != d.to_hash.object_id
  end
  
  def test_to_hash_returns_hash_with_mapped_and_unmapped_values_when_bound
    d.store[:one] = 'one'
    d.store[:key] = 'value'
    d.bind(r)
    assert_equal({:one => 'one', :key => 'value'}, d.to_hash)
    
    r.key = "VALUE"
    assert_equal({:one => 'one', :key => 'VALUE'}, d.to_hash)
  end
  
  def test_to_hash_recursively_hashifies_DelegateHash_values
    one = DelegateHash.new(
      {:a => Delegate.new(:key, :key=, 'value')}, 
      {:one => 'value'})
    two = DelegateHash.new(
      {:b => Delegate.new(:key, :key=, one)}, 
      {:two => 'value'})
    three = DelegateHash.new(
      {:d => Delegate.new(:key, :key=, 'value')}, 
      {:three => 'value'})
    d = DelegateHash.new(
      {:c => Delegate.new(:key, :key=, two)}, 
      {:e => three})
    
    assert_equal({
      :c => {
        :b => {
          :a => 'value',
          :one => 'value'
        },
        :two => 'value'
      },
      :e => {
        :d => 'value',
        :three => 'value'
      }
    }, d.to_hash)
  end
  
  #
  # dup test
  #
  
  def test_duplicate_store_is_distinct_from_parent
    duplicate = d.dup
    assert d.store.object_id != duplicate.store.object_id
  end
  
  def test_duplicate_is_unbound
    d.bind(r)
    duplicate = d.dup
    assert d.bound?
    assert !duplicate.bound?
  end
  
  def test_duplicate_delegates_are_the_same_object_as_parent
    duplicate = d.dup
    assert_equal d.delegates.object_id, duplicate.delegates.object_id
  end
  
  def test_duplicate_stores_delegate_values_from_receiver
    d.bind(r)
    d[:key] = 'VALUE'
    d[:another] = 'value'
    
    assert_equal 'VALUE', r.key
    assert_equal({:another => 'value'}, d.store)
    
    duplicate = d.dup
    
    assert_equal({:key => 'VALUE', :another => 'value'}, duplicate.store)
  end
end