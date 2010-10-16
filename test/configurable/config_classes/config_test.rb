require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes/config'

class ConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :c
  
  def setup
    @c = Config.new(:key)
  end
  
  #
  # initialize test
  #
  
  def test_sets_attributes_from_attrs
    caster = lambda {}
    uncaster = lambda {}
    
    c = Config.new(:KEY,
      :name     => 'NAME', 
      :reader   => :READER, 
      :writer   => :WRITER, 
      :default  => :DEFAULT,
      :caster   => caster,
      :uncaster => uncaster
    )
    
    assert_equal :KEY, c.key
    assert_equal 'NAME', c.name
    assert_equal :READER, c.reader
    assert_equal :WRITER, c.writer
    assert_equal :DEFAULT, c.default
    assert_equal caster, c.caster
    assert_equal uncaster, c.uncaster
    assert_equal true, c.attrs.frozen?
  end
  
  def test_initialize_determines_name_reader_and_writer_from_key
    c = Config.new(:key)
    assert_equal :key, c.key
    assert_equal 'key', c.name
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
  end
  
  def test_initialize_allows_arbitrary_keys_with_valid_name
    assert_equal 'string', Config.new('string').key
    assert_equal 1, Config.new(1, :name => 'one').key
  end
  
  def test_initialize_sets_default_attr_if_not_set
    config = Config.new(:key)
    assert_equal true, config.attrs.has_key?(:default)
    assert_equal nil, config.attrs[:default]
  end
  
  def test_initialize_respects_boolean_defaults
    assert_equal true, Config.new(:key, :default => true).default
    assert_equal false, Config.new(:key, :default => false).default
  end
  
  def test_initialize_raises_error_for_non_string_names
    err = assert_raises(RuntimeError) { Config.new(:key, :name => :sym) }
    assert_equal 'invalid name: :sym (not a String)', err.message
  end
  
  def test_config_raises_error_for_non_word_characters_in_name
    err = assert_raises(NameError) { Config.new(:key, :name => 'k,ey') }
    assert_equal 'invalid characters in name: "k,ey"', err.message
  end
  
  #
  # get test
  #
  
  def test_get_calls_reader_on_receiver
    receiver = Struct.new(:key).new('value')
    assert_equal 'value', c.get(receiver)
  end
  
  #
  # set test
  #
  
  def test_set_calls_writer_on_receiver_with_input
    receiver = Struct.new(:key).new(nil)
    
    assert_equal nil, receiver.key
    c.set(receiver, 'value')
    assert_equal 'value', receiver.key
  end
  
  #
  # cast test
  #
  
  def test_cast_calls_caster_with_input_and_returns_the_result
    upcase = lambda {|value| value.upcase }
    
    c = Config.new(:key, :caster => upcase)
    assert_equal 'ABC', c.cast('aBc')
  end
  
  #
  # import test
  #
  
  def test_import_writes_the_value_keyed_by_name_in_source_to_target_by_key
    source = {:key => 'KEY', 'key' => 'NAME'}
    target = {}
    assert_equal target, c.import(source, target)
    
    assert_equal({:key => 'NAME'}, target)
    assert_equal({:key => 'KEY', 'key' => 'NAME'}, source)
  end
  
  def test_import_writes_nothing_if_source_does_not_have_a_value_keyed_by_name
    assert_equal({}, c.import({:key => 'KEY'}))
  end
  
  #
  # export test
  #
  
  def test_export_writes_the_value_keyed_by_key_in_source_to_target_by_name
    source = {:key => 'KEY', 'key' => 'NAME'}
    target = {}
    assert_equal target, c.export(source, target)
    
    assert_equal({'key' => 'KEY'}, target)
    assert_equal({:key => 'KEY', 'key' => 'NAME'}, source)
  end
  
  def test_export_writes_nothing_if_source_does_not_have_a_value_keyed_by_key
    assert_equal({}, c.export({'key' => 'KEY'}))
  end
end
