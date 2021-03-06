require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_types'

class BooleanTypeTest < Test::Unit::TestCase
  include Configurable::ConfigTypes
  
  attr_reader :type
  
  def setup
    @type = BooleanType.new
  end
  
  #
  # cast test
  #
  
  def test_cast_returns_true_string_as_true
    assert_equal true, type.cast('true')
  end
  
  def test_cast_returns_false_string_as_false
    assert_equal false, type.cast('false')
  end
  
  def test_cast_returns_booleans_directoy
    assert_equal true, type.cast(true)
    assert_equal false, type.cast(false)
  end
  
  #
  # uncast test
  #
  
  def test_uncast_returns_booleans
    assert_equal true, type.uncast(true)
    assert_equal false, type.uncast(false)
  end
end