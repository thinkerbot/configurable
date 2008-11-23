require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/configuration_hash'

class ConfigurationHashTest < Test::Unit::TestCase
  Configuration = Configurable::Configuration
  ConfigurationHash = Configurable::ConfigurationHash
  
  class Receiver
    attr_accessor :key
    
    def initialize
      @key = nil
    end
  end

  attr_reader :d, :r
  
  def setup
    @r = Receiver.new
    @d = ConfigurationHash.new({:key => Configuration.new(:key)})
  end
  
  #
  # documentation test
  #
  
  class Sample
    attr_accessor :key
  end
  
  def test_documentation
    sample = Sample.new
    
    dhash = ConfigurationHash.new
    dhash.delegates[:key] = Configuration.new(:key)
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
    d = ConfigurationHash.new
    assert_equal(nil, d.receiver)
    assert_equal({}, d.store)
    assert_equal({}, d.delegates)
  end
  
  def test_initialize_binds_receiver
    r = Receiver.new
    d = ConfigurationHash.new({:key => Configuration.new(:key)}, r, {:key => 'value'})
    
    assert d.bound?
    assert_equal({}, d.store)
    assert_equal r, d.receiver
    assert_equal 'value', r.key
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
  
  def test_bind_does_not_delegate_values_to_delegates_without_a_writer
    d.delegates[:key].writer = nil
    d.store[:key] = 1
    d.store[:not_a_config] = 1
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, d.store)
    
    d.bind(r)
    
    assert_nil r.key
    assert_equal({:key => 1, :not_a_config => 1}, d.store)
  end
  
  def test_bind_redelegates_stored_values_if_bound_again_to_the_receiver
    assert_nil r.key
    
    d.store[:key] = 1
    d.bind(r)
    assert_equal 1, r.key
    
    d.store[:key] = 2
    d.bind(r)
    assert_equal 2, r.key
  end
  
  def test_bind_raises_error_for_nil_receiver
    e = assert_raise(ArgumentError) { d.bind(nil) }
    assert_equal "receiver cannot be nil", e.message
  end
  
  def test_bind_raises_error_if_already_bound
    d.bind(r)
    e = assert_raise(ArgumentError) { d.bind(Receiver.new) }
    assert_equal "already bound to: #{r}", e.message
  end
  
  def test_bind_returns_self
    assert_equal d, d.bind(r)
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
   
  def test_unbind_returns_receiver
    d.bind(r)
    assert_equal r, d.unbind
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
  
  def test_AGET_returns_stored_value_if_config_has_no_reader
    d.delegates[:key].reader = nil
    d.bind(r)
    
    assert_equal nil, d.store[:unmapped]
    d[:unmapped] = "value"
    assert_equal "value", d.store[:unmapped]
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
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_is_in_store_or_is_mapped
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
  
  def test_each_pair_pulls_value_from_store_when_config_has_no_reader
    d.delegates[:key].reader = nil
    
    d[:key] = 'value'
    d[:another] = 'value'
    
    results = {}
    d.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :another => 'value'}, results)
    
    d.bind(r)
    
    d.store[:key] = 'VALUE'
    results = {}
    d.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'VALUE', :another => 'value'}, results)
  end
  
  #
  # dup test
  #
  
  def test_duplicate_store_is_distinct_from_parent
    duplicate = d.dup
    assert_not_equal d.store.object_id, duplicate.store.object_id
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
  
  #
  # == test
  #
  
  def test_equals_compares_to_hash_values
    assert d == {}
    
    d[:one] = 'one'
    assert d == {:one => 'one'}
    
    d2 = ConfigurationHash.new({}, nil, {:one => 'one'})
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
    assert_not_equal d.store.object_id, d.to_hash.object_id
  end
  
  def test_to_hash_returns_hash_with_mapped_and_unmapped_values_when_bound
    d.store[:one] = 'one'
    d.store[:key] = 'value'
    d.bind(r)
    assert_equal({:one => 'one', :key => 'value'}, d.to_hash)
    
    r.key = "VALUE"
    assert_equal({:one => 'one', :key => 'VALUE'}, d.to_hash)
  end
end