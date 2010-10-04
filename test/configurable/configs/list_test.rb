require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/configs'

class ListTest < Test::Unit::TestCase
  List = Configurable::Configs::List
  
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
  
  def test_cast_validates_input_is_an_array
    err = assert_raises(ArgumentError) { c.cast(1) }
    assert_equal "invalid value for config: 1 (key)", err.message
  end
end