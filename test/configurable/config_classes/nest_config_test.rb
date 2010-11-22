require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'
require 'configurable/config_hash'
require 'ostruct'

class NestConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  ConfigHash = Configurable::ConfigHash
  
  class Parent < OpenStruct
  end
  
  class Child
    class << self; attr_accessor :configs; end
    attr_accessor :config
    
    def initialize(store={})
      @config = ConfigHash.new(store, self)
    end
    
    def initialize_copy(orig)
      super
      @config = ConfigHash.new(orig.config.store.dup, self)
    end
  end
  
  attr_accessor :nest
  
  def setup
    Child.configs = {}
    @nest = NestConfig.new(:key, :default => Child.new)
  end
  
  #
  # get test
  #
  
  def test_get_returns_configs_on_child_configurable
    child  = Child.new
    parent = Parent.new(:key => child)
    
    assert_equal child.config, nest.get(parent)
  end
  
  #
  # set test
  #
  
  def test_set_sets_child_configurable_on_receiver
    child  = Child.new
    parent = Parent.new
    
    nest.set(parent, child)
    assert_equal child, parent.key
  end
  
  def test_set_merges_non_configurable_values_on_existing_child
    child  = Child.new(:one => 'one')
    parent = Parent.new(:key => child)
    
    assert_equal 'one', child.config[:one]
    assert_equal nil,   child.config[:two]
    
    nest.set(parent, {:one => 'ONE', :two => 'TWO'})
    
    assert_equal 'ONE', child.config[:one]
    assert_equal 'TWO', child.config[:two]
  end
  
  def test_set_duplicates_configurable_to_initialize_missing_child
    nest.configurable.config[:one] = 'one'
    parent = Parent.new
    
    assert_equal nil, parent.key
    nest.set(parent, {:two => 'two'})
    
    child = parent.key
    assert_equal 'one', child.config[:one]
    assert_equal 'two', child.config[:two]
    
    assert_equal nil, nest.configurable.config[:two]
  end
end