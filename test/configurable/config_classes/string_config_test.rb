require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class StringConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :type
  
  def setup
    @type = StringConfig.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_returns_input_to_s
    assert_equal '1', type.cast(1)
  end
  
  #
  # uncast test
  #
  
  def test_uncast_returns_value_to_s
    assert_equal '1', type.uncast('1')
  end
end