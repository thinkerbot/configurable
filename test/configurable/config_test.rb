require File.join(File.dirname(__FILE__), '../tap_test_helper')
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
    [nil, 1, 1.1, true, false, :sym, NonDuplicable.new].each do |non_duplicable_value|
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
    c = Config.new('key', 'default', 'key', 'key=', :attr => 'value')
    assert_equal 'key', c.key
    assert_equal 'default', c.default
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal({:attr => 'value'}, c.attributes)
  end
  
  def test_initialize_using_defaults
    c = Config.new('key')
    assert_equal 'key', c.key
    assert_equal nil, c.default
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal({}, c.attributes)
  end
  
  def test_reader_and_writer_may_be_set_to_nil_during_initialize
    c = Config.new('key', 'default', nil, nil)
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
    config = Config.new('key', 'default', 'key', 'key=')
    another = Config.new('key', 'default', 'key', 'key=')
    assert config == another
    
    another = Config.new('alt', 'default', 'key', 'key=')
    assert config != another
    
    another = Config.new('key', 'alt', 'key', 'key=')
    assert config != another
    
    another = Config.new('key', 'default', 'alt', 'key=')
    assert config != another
    
    another = Config.new('key', 'default', 'key', 'alt=')
    assert config != another
  end
  
  def test_equal_does_not_consider_attributes
    config = Config.new('key')
    another = Config.new('key')
    another.attributes[:attr] = 'value'
    
    assert config.attributes != another.attributes
    assert config == another
  end
end
