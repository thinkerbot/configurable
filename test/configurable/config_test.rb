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
  
  def test_initialize_determines_reader_and_writer_from_name
    c = Config.new(:key)
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal nil, c.default
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
end
