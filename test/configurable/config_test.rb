require File.expand_path('../../test_helper', __FILE__) 
require 'configurable/config'

class ConfigTest < Test::Unit::TestCase
  Config = Configurable::Config
  
  attr_reader :c
  
  def setup
    @c = Config.new(:key)
  end
  
  #
  # initialize test
  #
  
  def test_sets_attributes_from_attrs
    caster = lambda {}
    
    c = Config.new(:KEY,
     :name => 'NAME', 
     :reader => :READER, 
     :writer => :WRITER, 
     :default => :DEFAULT,
     :caster => caster
    )
    
    assert_equal :KEY, c.key
    assert_equal 'NAME', c.name
    assert_equal :READER, c.reader
    assert_equal :WRITER, c.writer
    assert_equal :DEFAULT, c.default
    assert_equal caster, c.caster
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
  # map_by_key test
  #
  
  def test_map_by_key_writes_the_value_keyed_by_name_in_source_to_target_by_key
    source = {:key => 'KEY', 'key' => 'NAME'}
    target = {}
    assert_equal target, c.map_by_key(source, target)
    
    assert_equal({:key => 'NAME'}, target)
    assert_equal({:key => 'KEY', 'key' => 'NAME'}, source)
  end
  
  def test_map_by_key_writes_nothing_if_source_does_not_have_a_value_keyed_by_name
    assert_equal({}, c.map_by_key({:key => 'KEY'}))
  end
  
  #
  # map_by_name test
  #
  
  def test_map_by_name_writes_the_value_keyed_by_key_in_source_to_target_by_name
    source = {:key => 'KEY', 'key' => 'NAME'}
    target = {}
    assert_equal target, c.map_by_name(source, target)
    
    assert_equal({'key' => 'KEY'}, target)
    assert_equal({:key => 'KEY', 'key' => 'NAME'}, source)
  end
  
  def test_map_by_name_writes_nothing_if_source_does_not_have_a_value_keyed_by_key
    assert_equal({}, c.map_by_name({'key' => 'KEY'}))
  end
  
  #
  # cast test
  #
  
  def test_cast_calls_caster_with_input_and_returns_the_result
    upcase = lambda {|value| value.upcase }
    
    c = Config.new(:key, :caster => upcase)
    assert_equal 'ABC', c.cast('aBc')
  end
end
