require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class ConfigHashTest < Test::Unit::TestCase
  Config = Configurable::Config
  ConfigHash = Configurable::ConfigHash
  
  class Receiver
    include Configurable
    config :key
    
    # initialize without initializing configs
    # so that receiver acts as a stub
    def initialize; end
  end
  
  #
  # setup
  #
  
  attr_reader :config_hash
  
  def setup
    @config_hash = ConfigHash.new(Receiver.new)
  end
  
  #
  # documentation test
  #
  
  class Sample
    include Configurable
    config :key
  end
  
  def test_documentation
    sample = Sample.new
    assert_equal ConfigHash, sample.config.class
  
    sample.key = 'value'
    assert_equal 'value', sample.config[:key]
  
    sample.config[:key] = 'another'
    assert_equal 'another', sample.key

    sample.config[:not_delegated] = 'value'
    assert_equal 'value', sample.config[:not_delegated]
    
    assert_equal({:not_delegated => 'value'}, sample.config.store)
    assert_equal({:key => 'another', :not_delegated => 'value'}, sample.config.to_hash)
    
    ###
    
    config_hash = Sample.new.config
    config_hash[:key] = 'a'
    config_hash.store[:key] = 'b'
  
    assert_equal 'a', config_hash[:key]
    assert_equal({:key => 'b'}, config_hash.to_hash)
    assert_equal true, config_hash.inconsistent?
  
    config_hash.import(config_hash.store)
  
    assert_equal 'b', config_hash[:key]
    assert_equal({:key => 'b'}, config_hash.to_hash)
    assert_equal false, config_hash.inconsistent?
  end
  
  #
  # initialization test
  #
  
  def test_initialize
    receiver = Receiver.new
    store = {}
    config_hash = ConfigHash.new(receiver, store)
    
    assert_equal(receiver, config_hash.receiver)
    assert_equal(store, config_hash.store)
  end
  
  def test_initialize_imports_store_to_receiver
    receiver = Receiver.new
    receiver.key = "existing value"
    
    config_hash = ConfigHash.new(receiver, {:key => 'new value'})
    assert_equal({}, config_hash.store)
    assert_equal "new value", receiver.key
  end
  
  def test_initialize_does_not_import_store_to_receiver_if_specified
    receiver = Receiver.new
    receiver.key = "existing value"
    
    config_hash = ConfigHash.new(receiver, {:key => 'new value'}, false)
    assert_equal({:key => 'new value'}, config_hash.store)
    assert_equal "existing value", receiver.key
  end
  
  #
  # inconsistent? test
  #
  
  def test_inconsistent_returns_true_if_the_store_has_values_that_could_be_stored_on_receiver
    assert_equal false, config_hash.inconsistent?
    
    config_hash.store[:key] = 'value'
    assert_equal true, config_hash.inconsistent?
    
    config_hash.store.delete(:key)
    assert_equal false, config_hash.inconsistent?
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_value_stored_on_receiver
    config_hash.store[:key] = 'config_hash value'
    
    config_hash.receiver.key = nil
    assert_equal nil, config_hash[:key]
    
    config_hash.receiver.key = "receiver value"
    assert_equal 'receiver value', config_hash[:key]
  end
  
  def test_AGET_returns_store_value_if_unable_to_store_on_receiver
    config_hash.store[:alt] = 'config_hash value'
    assert_equal 'config_hash value', config_hash[:alt]
  end
  
  #
  # ASET test
  #
  
  def test_ASET_stores_value_on_receiver
    assert_equal nil, config_hash.receiver.key
    config_hash[:key] = 'value'
    assert_equal "value", config_hash.receiver.key
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
    
    assert_equal [:key], config_hash.configs.keys
    assert_equal [:alt], config_hash.store.keys
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
    
    another = ConfigHash.new(Receiver.new, :key => 'VALUE', :b => 'B')
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
    a = ConfigHash.new(Receiver.new, :a => 'value')
    b = ConfigHash.new(Receiver.new, :b => a)
    c = ConfigHash.new(Receiver.new, :c => b)
    
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
    a = ConfigHash.new(Receiver.new, :a => 'value')
    b = ConfigHash.new(Receiver.new, :b => a)
    c = ConfigHash.new(Receiver.new, :c => b)
    
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
    config_hash.store[:alt] = nil
    config_hash.receiver.key = nil
  
    assert_equal({:alt => nil, :key => nil}, config_hash.to_hash)
    assert_equal({:alt => nil}, config_hash.to_hash(true))
    
    config_hash.receiver.key = :value
    assert_equal({:alt => nil, :key => :value}, config_hash.to_hash(true))
  end
  
  def test_to_hash_scrubs_delgates_recursively
    a = ConfigHash.new(Receiver.new, :a => 'value')
    b = ConfigHash.new(Receiver.new, :b => a)
    c = ConfigHash.new(Receiver.new, :c => b)
    
    assert_equal({
      :c => {:b => {:a => 'value'}}
    }, c.to_hash(true))
  end
  
  #
  # == test
  #
  
  def test_equals_compares_to_hash_values
    config_hash = ConfigHash.new(Receiver.new)
    assert config_hash == {:key => nil}
    
    config_hash[:key] = 'value'
    config_hash[:alt] = 'VALUE'
    assert config_hash == {:key => 'value', :alt => 'VALUE'}
    
    another = ConfigHash.new(Receiver.new, {:key => 'value', :alt => 'VALUE'})
    assert config_hash == another
  end
end