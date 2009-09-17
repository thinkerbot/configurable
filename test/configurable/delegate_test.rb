require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/delegate'
require 'configurable/delegate_hash'

class DelegateTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  
  attr_reader :c
  
  def setup
    @c = Delegate.new('key', 'key=', nil)
  end
  
  #
  # Delegate.duplicable_value?
  #
  
  class NonDuplicable
    undef_method :dup
  end
  
  def test_duplicable_value_is_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym, NonDuplicable.new].each do |non_duplicable_value|
      assert !Delegate.duplicable_value?(non_duplicable_value)
    end
  end
  
  def test_duplicable_value_is_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_value|
      assert Delegate.duplicable_value?(duplicable_value)
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Delegate.new('key', 'key=', 'default', :attr => 'value')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal 'default', c.default
    assert_equal({:attr => 'value'}, c.attributes)
  end
  
  def test_initialize_using_defaults
    c = Delegate.new('key')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal nil, c.default
    assert_equal({}, c.attributes)
  end
  
  def test_reader_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { Delegate.new(nil) }
    assert_equal "reader may not be nil", e.message
  end
  
  def test_writer_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { Delegate.new('key', nil) }
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
  # default test
  #

  def test_default_returns_default
    assert_equal nil, c.default
    
    c = Delegate.new(:reader, :writer, 'default')
    assert_equal 'default', c.default
  end
  
  def test_default_returns_duplicate_values
    a = [1,2,3]
    c = Delegate.new(:reader, :writer, a)
  
    assert_equal a, c.default
    assert a.object_id != c.default.object_id
  end
  
  def test_default_does_not_duplicate_if_default_is_not_duplicable
    a = NonDuplicable.new
    c = Delegate.new(:reader, :writer, a)
    
    assert_equal a.object_id, c.default.object_id
  end
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_key_default_reader_and_writer_are_equal
    config = Delegate.new('key', 'key=', 'default')
    another = Delegate.new('key', 'key=', 'default')
    assert config == another
    
    config = Delegate.new('key', 'key=', 'default')
    another = Delegate.new('alt', 'key=', 'default')
    assert config != another
    
    config = Delegate.new('key', 'key=', 'default')
    another = Delegate.new('key', 'alt=', 'default')
    assert config != another
    
    config = Delegate.new('key', 'key=', 'default')
    another = Delegate.new('key', 'key=', 'alt')
    assert config != another
  end
  
  def test_equal_does_not_consider_attributes
    config = Delegate.new('key')
    another = Delegate.new('key')
    another.attributes[:attr] = 'value'
    
    assert config.attributes != another.attributes
    assert config == another
  end
end
