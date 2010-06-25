require File.expand_path('../../test_helper.rb', __FILE__) 
require 'configurable/config'

class ConfigTest < Test::Unit::TestCase
  Config = Configurable::Config
  
  attr_reader :c
  
  def setup
    @c = Config.new('key')
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Config.new('key', 'key=', 'default', {:attr => 'value'}, false, true)
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal 'default', c.default
    assert_equal({:attr => 'value'}, c.attributes)
    assert_equal false, c.init?
    assert_equal true, c.duplicate?
  end
  
  def test_initialize_defaults
    c = Config.new('key')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal nil, c.default
    assert_equal({}, c.attributes)
    assert_equal true, c.init?
    assert_equal false, c.duplicate?
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
    
    default = 'default'
    c = Config.new(:reader, :writer, default, {}, true, false)
    
    assert_equal default, c.default
    assert default.object_id == c.default.object_id
  end
  
  def test_default_duplicates_default_if_duplicable_and_specified
    default = 'default'
    c = Config.new(:reader, :writer, default, {}, true, true)
    
    assert_equal default, c.default
    assert default.object_id != c.default.object_id
    
    assert_equal default, c.default(false)
    assert default.object_id == c.default(false).object_id
  end
  
  def test_default_duplicates_default_using_the_dup_method
    default = 'default'
    c = Config.new(:reader, :writer, default, {}, true, :object_id)
    assert_equal default.object_id, c.default
  end
end
