require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
  
  attr_reader :config
  
  def setup
    @config = Config.new(:key)
  end
  
  #
  # initialize test
  #
  
  def test_sets_attributes_from_attrs
    config = Config.new(:KEY,
      :name    => 'NAME', 
      :reader  => :READER, 
      :writer  => :WRITER, 
      :default => :DEFAULT,
      :desc    => {:long => 'LONG'}
    )
    
    assert_equal :KEY,     config.key
    assert_equal 'NAME',   config.name
    assert_equal :READER,  config.reader
    assert_equal :WRITER,  config.writer
    assert_equal :DEFAULT, config.default
    assert_equal({:long => 'LONG'}, config.desc)
  end
  
  def test_initialize_determines_name_reader_and_writer_from_key
    config = Config.new(:key)
    assert_equal :key,  config.key
    assert_equal 'key', config.name
    assert_equal :key,  config.reader
    assert_equal :key=, config.writer
  end
  
  def test_initialize_allows_arbitrary_keys_with_valid_name
    assert_equal 'string', Config.new('string').key
    assert_equal 1, Config.new(1, :name => 'one').key
  end
  
  def test_initialize_sets_default_to_nil_if_unspecified
    config = Config.new(:key)
    assert_equal nil, config.default
  end
  
  def test_initialize_respects_boolean_defaults
    assert_equal true,  Config.new(:key, :default => true).default
    assert_equal false, Config.new(:key, :default => false).default
  end
  
  def test_initialize_raises_error_for_non_string_names
    err = assert_raises(RuntimeError) { Config.new(:key, :name => :sym) }
    assert_equal 'invalid name: :sym (not a String)', err.message
  end
  
  def test_config_raises_error_for_non_word_characters_in_name
    err = assert_raises(NameError) { Config.new(:key, :name => 'k,ey') }
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
  
  #
  # cast test
  #
  
  def test_cast_casts_input_using_type
    config = Config.new(:key, :type => IntegerType.new)
    assert_equal 1, config.cast('1')
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_value_using_type
    config = Config.new(:key, :type => IntegerType.new)
    assert_equal '1', config.uncast(1)
  end
end
