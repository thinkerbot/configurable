require File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configuration'

class ConfigurationTest < Test::Unit::TestCase
  attr_reader :c
  
  def setup
    @c = Configuration.new('key', 'key=', nil)
  end
  
  #
  # Configuration.duplicable_value?
  #
  
  class NonDuplicable
    undef_method :dup
  end
  
  def test_duplicable_value_is_false_if_default_cannot_be_duplicated
    [nil, 1, 1.1, true, false, :sym, NonDuplicable.new].each do |non_duplicable_value|
      assert !Configuration.duplicable_value?(non_duplicable_value)
    end
  end
  
  def test_duplicable_value_is_true_if_default_can_be_duplicated
    [{}, [], Object.new].each do |duplicable_value|
      assert Configuration.duplicable_value?(duplicable_value)
    end
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = Configuration.new('key', 'key=', 'default', :attr => 'value')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal 'default', c.default
    assert_equal({:attr => 'value'}, c.attributes)
  end
  
  def test_initialize_using_defaults
    c = Configuration.new('key')
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal nil, c.default
    assert_equal({}, c.attributes)
  end
  
  def test_reader_and_writer_may_be_set_to_nil_during_initialize
    c = Configuration.new(nil, nil, 'default')
    assert_equal nil, c.reader
    assert_equal nil, c.writer
  end
  
  #
  # default= test
  #
  
  def test_set_default_sets_default
    assert_nil c.default
    c.default = 1
    assert_equal 1, c.default
  end
  
  def test_set_default_freezes_object
    a = []
    assert !a.frozen?
    c.default = a
    assert a.frozen?
  end
  
  def test_non_freezable_objects_are_not_frozen
    c.default = 1
    assert !c.default.frozen?
    
    c.default = :sym
    assert !c.default.frozen?
    
    c.default = nil
    assert !c.default.frozen?
  end
  
  #
  # default test
  #

  def test_default_returns_default
    assert_equal nil, c.default
    
    c.default = 'value'
    assert_equal 'value', c.default
  end
  
  def test_default_returns_duplicate_values
    a = [1,2,3]
    c.default = a
  
    assert_equal a, c.default
    assert_not_equal a.object_id, c.default.object_id
  end
  
  def test_default_does_not_duplicate_if_specified
    a = [1,2,3]
    c.default = a
  
    assert_equal a, c.default(false)
    assert_equal a.object_id, c.default(false).object_id
  end
  
  def test_default_does_not_duplicate_if_default_is_not_duplicable
    a = NonDuplicable.new
    c.default = a
    
    assert_equal a.object_id, c.default(false).object_id
    assert_equal a.object_id, c.default.object_id
  end
  
  #
  # reader= test
  #

  def test_set_reader_symbolizes_input
    c.reader = 'reader'
    assert_equal :reader, c.reader
  end
  
  def test_reader_may_be_set_to_nil
    c.reader = nil
    assert_equal nil, c.reader
  end
  
  #
  # writer= test
  #

  def test_set_writer_symbolizes_input
    c.writer = 'writer='
    assert_equal :writer=, c.writer
  end  
  
  def test_writer_may_be_set_to_nil
    c.writer = nil
    assert_equal nil, c.writer
  end
  
  #
  # == test
  #
  
  def test_another_is_equal_to_self_if_key_default_reader_and_writer_are_equal
    config = Configuration.new('key', 'key=', 'default')
    another = Configuration.new('key', 'key=', 'default')
    assert config == another
    
    config = Configuration.new('key', 'key=', 'default')
    another = Configuration.new('alt', 'key=', 'default')
    assert config != another
    
    config = Configuration.new('key', 'key=', 'default')
    another = Configuration.new('key', 'alt=', 'default')
    assert config != another
    
    config = Configuration.new('key', 'key=', 'default')
    another = Configuration.new('key', 'key=', 'alt')
    assert config != another
  end
  
  def test_equal_does_not_consider_attributes
    config = Configuration.new('key')
    another = Configuration.new('key')
    another.attributes[:attr] = 'value'
    
    assert config.attributes != another.attributes
    assert config == another
  end
end
