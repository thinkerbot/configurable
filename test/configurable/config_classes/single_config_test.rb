require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ScalarConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :config
  
  def setup
    @config = ScalarConfig.new(:key)
  end
  
  #
  # initialize test
  #
  
  def test_sets_attributes_from_attrs
    config = ScalarConfig.new(:KEY,
      :name     => 'NAME', 
      :reader   => :READER, 
      :writer   => :WRITER, 
      :default  => :DEFAULT,
      :metadata => {:long => 'LONG'}
    )
    
    assert_equal :KEY,     config.key
    assert_equal 'NAME',   config.name
    assert_equal :READER,  config.reader
    assert_equal :WRITER,  config.writer
    assert_equal :DEFAULT, config.default
    assert_equal({:long => 'LONG'}, config.metadata)
  end
  
  def test_initialize_determines_name_reader_and_writer_from_key
    config = ScalarConfig.new(:key)
    assert_equal :key,  config.key
    assert_equal 'key', config.name
    assert_equal :key,  config.reader
    assert_equal :key=, config.writer
  end
  
  def test_initialize_allows_arbitrary_keys_with_valid_name
    assert_equal 'string', ScalarConfig.new('string').key
    assert_equal 1, ScalarConfig.new(1, :name => 'one').key
  end
  
  def test_initialize_sets_default_to_nil_if_unspecified
    config = ScalarConfig.new(:key)
    assert_equal nil, config.default
  end
  
  def test_initialize_respects_boolean_defaults
    assert_equal true,  ScalarConfig.new(:key, :default => true).default
    assert_equal false, ScalarConfig.new(:key, :default => false).default
  end
  
  def test_initialize_raises_error_for_non_string_names
    err = assert_raises(RuntimeError) { ScalarConfig.new(:key, :name => :sym) }
    assert_equal 'invalid name: :sym (not a String)', err.message
  end
  
  def test_config_raises_error_for_non_word_characters_in_name
    err = assert_raises(NameError) { ScalarConfig.new(:key, :name => 'k,ey') }
    assert_equal 'invalid name: "k,ey" (includes non-word characters)', err.message
  end
  
  #
  # get test
  #
  
  def test_get_calls_reader_on_receiver
    receiver = Struct.new(:key).new('value')
    assert_equal 'value', config.get(receiver)
  end
  
  #
  # set test
  #
  
  def test_set_calls_writer_on_receiver_with_input
    receiver = Struct.new(:key).new(nil)
    assert_equal nil, receiver.key
    
    config.set(receiver, 'value')
    assert_equal 'value', receiver.key
  end
end
