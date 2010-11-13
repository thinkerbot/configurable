require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ListTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
  
  attr_reader :c
  
  def setup
    @c = List.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    c = List.new(:key, :type => IntegerType.new)
    
    input = [1,'2',3]
    output = c.cast(input)
    
    assert_equal [1,2,3], output
    assert input.object_id != output.object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_each_value_of_the_input
    c = List.new(:key, :type => StringType.new)
    
    input = [1,2,3]
    output = c.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
  
  #
  # errors test
  #
  
  def test_errors_returns_nil_if_each_value_in_values_is_valid
    c = List.new(:key)
    assert_equal nil, c.errors([1,3])
    
    c = List.new(:key, :options => [1,2,3])
    assert_equal nil, c.errors([1,3])
  end
  
  def test_errors_error_messages_for_each_invalid_value_in_values
    c = List.new(:key, :options => [1,2,3])
    assert_equal [
      'invalid value: 6',
      'invalid value: 8'
    ], c.errors([6,3,8])
  end
end