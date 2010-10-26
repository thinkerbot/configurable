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
    uncaster = lambda {|value| value.to_s }
    c = List.new(:key, :uncaster => uncaster)
    
    input = [1,2,3]
    output = c.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
end