require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ListTest < Test::Unit::TestCase
  include Configurable::ConfigClasses

  attr_reader :list
  
  def setup
    @list = ObjectConfig.new(:key).extend List
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    list = IntegerConfig.new(:key).extend List
    
    input = [1,'2',3]
    output = list.cast(input)
    
    assert_equal [1,2,3], output
    assert input.object_id != output.object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_each_value_of_the_input
    list = IntegerConfig.new(:key).extend List
    
    input = [1,'2',3]
    output = list.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
end