require File.expand_path('../../test_helper', __FILE__)
require 'configurable/config_hash'
require 'configurable/config_classes'

class ConfigHashTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  ConfigHash = Configurable::ConfigHash
  
  class Receiver
    include Configurable::ConfigClasses
    
    def self.configs
      @configs ||= {:key => ScalarConfig.new(:key)}
    end
    
    attr_accessor :key
  end
  
  #
  # setup
  #
  
  attr_reader :config_hash
  
  def setup
    @config_hash = ConfigHash.new.bind(Receiver.new)
  end
  
  #
  # initialization test
  #
  
  def test_initialize_sets_store_directly
    store = {}
    config_hash = ConfigHash.new(store)
    assert_equal store.object_id, config_hash.store.object_id
  end
  
  def test_initialize_does_not_import_store_to_receiver
    receiver = Receiver.new
    receiver.key = 'current'
    
    config_hash = ConfigHash.new({:key => 'new'}, receiver)
    assert_equal({:key => 'new'}, config_hash.store)
    assert_equal 'current', receiver.key
  end
  
  #
  # bind test
  #
  
  #
  # unbind test
  #
  
  #
  # bound? test
  #
  
  def test_bound_returns_true_if_a_receiver_is_set
    config_hash = ConfigHash.new
    assert_equal nil, config_hash.receiver
    assert_equal false, config_hash.bound?
    
    receiver = Receiver.new
    config_hash.bind(receiver)
    assert_equal receiver, config_hash.receiver
    assert_equal true, config_hash.bound?
  end
  
  #
  # consistent? test
  #
  
  def test_consistent_returns_true_if_the_store_has_no_entries_that_could_be_stored_on_receiver
    assert_equal true, config_hash.consistent?
    
    config_hash.store[:key] = 'value'
    assert_equal false, config_hash.consistent?
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_value_stored_on_receiver
    config_hash.store[:key] = 'store value'
    
    config_hash.receiver.key = nil
    assert_equal nil, config_hash[:key]
    
    config_hash.receiver.key = "receiver value"
    assert_equal 'receiver value', config_hash[:key]
  end
  
  def test_AGET_returns_store_value_if_unable_to_store_on_receiver
    config_hash.store[:alt] = 'store value'
    assert_equal 'store value', config_hash[:alt]
  end
  
  #
  # ASET test
  #
  
  def test_ASET_stores_value_on_receiver
    assert_equal nil, config_hash.receiver.key
    config_hash[:key] = 'value'
    assert_equal 'value', config_hash.receiver.key
  end
  
  def test_ASET_stores_value_in_store_if_unable_to_store_on_receiver
    assert_equal nil, config_hash.receiver.key
    assert_equal({}, config_hash.store)
    
    config_hash[:alt] = 'value'
    
    assert_equal nil, config_hash.receiver.key
    assert_equal({:alt => 'value'}, config_hash.store)
  end
  
  #
  # keys test
  #
  
  def test_keys_returns_union_of_configs_keys_and_store_keys
    config_hash.store[:alt] = nil
    assert_equal [:key, :alt], config_hash.keys
  end
  
  #
  # has_key? test
  #
  
  def test_has_key_is_true_if_the_key_is_a_key_in_configs_or_store
    config_hash.store[:alt] = 'value'
    
    assert config_hash.has_key?(:key)
    assert config_hash.has_key?(:alt)
    assert !config_hash.has_key?(:not_a_key)
  end
  
  #
  # merge! test
  #
  
  def test_merge_merges_another_with_self
    config_hash[:key] = 'value'
    config_hash[:a] = 'a'
    
    assert_equal 'value', config_hash.receiver.key
    assert_equal({:a => 'a'}, config_hash.store)
    
    config_hash.merge!(:key => 'VALUE', :b => 'B')
    assert_equal 'VALUE', config_hash.receiver.key
    assert_equal({:a => 'a', :b => 'B'}, config_hash.store)
  end
  
  def test_merge_can_merge_another_ConfigHash
    config_hash[:key] = 'value'
    config_hash[:a] = 'a'
    assert_equal 'value', config_hash.receiver.key
    assert_equal({:a => 'a'}, config_hash.store)
    
    another = ConfigHash.new(:key => 'VALUE', :b => 'B').bind(Receiver.new)
    assert_equal 'VALUE', another.receiver.key
    assert_equal({:b => 'B'}, another.store)
    
    config_hash.merge!(another)
    assert_equal 'VALUE', config_hash.receiver.key
    assert_equal({:a => 'a', :b => 'B'}, config_hash.store)
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_yields_each_key_value_pair_stored_in_self
    config_hash[:key] = 'value'
    config_hash[:alt] = 'VALUE'
    
    results = {}
    config_hash.each_pair {|key, value| results[key] = value }
    assert_equal({:key => 'value', :alt => 'VALUE'}, results)
  end
  
  #
  # to_hash test
  #
  
  def test_to_hash_returns_hash_merging_receiver_and_store_entries
    config_hash.store[:alt] = 'VALUE'
    config_hash.receiver.key = 'value'
    
    assert_equal({:key => 'value', :alt => 'VALUE'}, config_hash.to_hash)
  end
  
  def test_to_hash_recursively_hashifies_ConfigHash_values
    a = ConfigHash.new(:a => 'value').bind(Receiver.new)
    b = ConfigHash.new(:b => a).bind(Receiver.new)
    c = ConfigHash.new(:c => b).bind(Receiver.new)
    
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
  
  #
  # == test
  #
  
  def test_equals_compares_to_hash_values
    config_hash = ConfigHash.new.bind(Receiver.new)
    assert config_hash == {:key => nil}
    
    config_hash[:key] = 'value'
    config_hash[:alt] = 'VALUE'
    assert config_hash == {:key => 'value', :alt => 'VALUE'}
    
    another = ConfigHash.new(:key => 'value', :alt => 'VALUE').bind(Receiver.new)
    assert config_hash == another
  end
end