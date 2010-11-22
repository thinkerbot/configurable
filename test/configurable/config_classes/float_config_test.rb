require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class FloatConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :type
  
  def setup
    @type = FloatConfig.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_returns_input_converted_to_float
    assert_equal 1.1, type.cast('1.1')
  end
  
  #
  # uncast test
  #
  
  def test_uncast_returns_value
    assert_equal 1.1, type.uncast(1.1)
  end
end