require File.expand_path('../../test_helper.rb', __FILE__) 
require 'configurable/config'

class ConfigTest < Test::Unit::TestCase
  Config = Configurable::Config
  
  attr_reader :c
  
  def setup
    @c = Config.new('key')
  end
  
  #
  # Config.duplicable_value?
  #
  
  class NonDuplicable
    undef_method :dup
  end
  
  def test_duplicable_value_is_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym, NonDuplicable, NonDuplicable.new].each do |non_duplicable_value|
      assert !Config.duplicable_value?(non_duplicable_value)
    end
  end
  
  def test_duplicable_value_is_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_value|
      assert Config.duplicable_value?(duplicable_value)
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Config.new('key', 'key=', 'default', {:attr => 'value'}, false)
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal 'default', c.default
    assert_equal false, c.init?
    assert_equal({:attr => 'value'}, c.attributes)
  end
  
  def test_initialize_using_defaults
    c = Config.new('key')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal nil, c.default
    assert_equal true, c.init?
    assert_equal({}, c.attributes)
  end
  
  def test_reader_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { Config.new(nil) }
    assert_equal "reader may not be nil", e.message
  end
  
  def test_writer_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { Config.new('key', nil) }
    assert_equal "writer may not be nil", e.message
  end
  
  #
  # AGET test
  #
  
  def test_AGET_returns_attribute_value_if_specified
    c.attributes[:key] = 'value'
    assert_equal 'value', c[:key]
  end
  
  def test_AGET_returns_default_value_if_attribute_is_not_specified
    assert !c.attributes.has_key?(:key)
    assert_equal 'value', c[:key, 'value']
  end
  
  #
  # get test
  #
  
  def test_get_calls_reader_on_receiver
    receiver = Struct.new(:key).new("value")
    c = Config.new(:key)
    
    assert_equal "value", c.get(receiver)
  end
  
  #
  # set test
  #
  
  def test_set_calls_writer_on_receiver_with_input
    receiver = Struct.new(:key).new(nil)
    c = Config.new(:key, :key=)
    
    assert_equal nil, receiver.key
    c.set(receiver, "value")
    assert_equal "value", receiver.key
  end
  
  #
  # init test
  #
  
  def test_init_sets_default_on_receiver
    receiver = Struct.new(:key).new(nil)
    c = Config.new(:key, :key=, "default")
    
    assert_equal nil, receiver.key
    c.init(receiver)
    assert_equal "default", receiver.key
  end
  
  #
  # default test
  #

  def test_default_returns_default
    assert_equal nil, c.default
    
    c = Config.new(:reader, :writer, 'default')
    assert_equal 'default', c.default
  end
  
  def test_default_duplicates_default_if_duplicable
    default = 'default'
    assert_equal true, Config.duplicable_value?(default)
    
    c = Config.new(:reader, :writer, default)
    
    assert_equal default, c.default
    assert default.object_id != c.default.object_id
  end
  
  def test_default_does_not_duplicate_default_if_non_duplicable
    default = Object
    assert_equal false, Config.duplicable_value?(default)
    
    c = Config.new(:reader, :writer, default)
    assert default.object_id == c.default.object_id
  end
  
  def test_default_duplicates_non_duplicable_values_if_dup_is_true
    default = Object
    assert_equal false, Config.duplicable_value?(default)
    
    c = Config.new(:reader, :writer, default, {}, true, true)
    assert default.object_id != c.default.object_id
  end
  
  def test_default_does_not_duplicate_unless_specified
    default = 'default'
    c = Config.new(:reader, :writer, default)
    
    assert_equal default, c.default
    assert default.object_id != c.default.object_id
    
    assert_equal default, c.default(false)
    assert default.object_id == c.default(false).object_id
  end
end
