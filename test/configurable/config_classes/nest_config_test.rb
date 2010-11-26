require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'
require 'configurable/config_hash'
require 'ostruct'

class NestConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  ConfigHash = Configurable::ConfigHash
  
  class Parent < OpenStruct
  end
  
  class Child < OpenStruct
  end
  
  class ChildType
    def init(config)
      Child.new(:config => config)
    end
  end
  
  attr_accessor :nest
  
  def setup
    @nest = NestConfig.new(:child, :type => ChildType.new)
  end
  
  #
  # get test
  #
  
  def test_get_returns_config_on_child
    child  = Child.new(:config => 'config')
    parent = Parent.new(:child => child)
    
    assert_equal 'config', nest.get(parent)
  end
  
  #
  # set test
  #
  
  def test_set_sets_input_as_child_if_it_responds_to_config
    child  = Child.new(:config => 'config')
    parent = Parent.new
    
    nest.set(parent, child)
    assert_equal child, parent.child
  end
  
  def test_set_initializes_child_using_type_if_input_does_not_respond_to_config
    parent = Parent.new
    
    nest.set(parent, {:key => 'value'})
    child = parent.child
    
    assert_equal Child, child.class
    assert_equal({:key => 'value'}, child.config)
  end
  
  def test_set_merges_input_with_defaults_before_initializing_child
    parent = Parent.new
    
    nest.default[:one] = 'one'
    nest.default[:two] = 'two'
    nest.set(parent, {:two => 'TWO', :three => 'THREE'})
    
    assert_equal({
      :one   => 'one',
      :two   => 'TWO', 
      :three => 'THREE'
    }, parent.child.config)
  end
end