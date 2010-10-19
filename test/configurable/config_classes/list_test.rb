require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ListTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :c
  
  def setup
    @c = List.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    caster = lambda {|value| value.to_i }
    c = List.new(:key, :caster => caster)
    
    input = [1,'2',3]
    output = c.cast(input)
    
    assert_equal [1,2,3], output
    assert input.object_id != output.object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_each_value_of_the_input
    caster = lambda {|value| value.to_i }
    c = List.new(:key, :caster => caster)
    
    input = [1,2,3]
    output = c.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
  
  #
  # check test
  #
  
  def test_check_validates_each_input_is_included_in_options
    c = List.new(:key, :options => [1,2,3])
    assert_equal [1], c.check([1])
    
    err = assert_raises(ArgumentError) { c.check([1,10,2]) }
    assert_equal "invalid value for config: 10 (key)", err.message
  end
end