require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_types'

class ObjectTypeTest < Test::Unit::TestCase
  include Configurable::ConfigTypes
  
  attr_reader :type
  
  def setup
    @type = ObjectType.new
  end
  
  #
  # cast test
  #
  
  def test_cast_returns_input
    obj = Object.new
    assert_equal obj.object_id, type.cast(obj).object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_returns_value
    obj = Object.new
    assert_equal obj.object_id, type.uncast(obj).object_id
  end
end