require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/configs'

class ListSelectTest < Test::Unit::TestCase
  ListSelect = Configurable::Configs::ListSelect
  
  attr_reader :c
  
  def setup
    @c = ListSelect.new(:key, :options => [1,2,3])
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    caster = lambda {|value| value.to_i }
    c = ListSelect.new(:key, :caster => caster, :options => [1,2,3])
    
    input = [1,'2',3]
    output = c.cast(input)
    
    assert_equal [1,2,3], output
    assert input.object_id != output.object_id
  end
  
  def test_cast_validates_each_input_value_is_in_options
    assert_equal [1], c.cast([1])
    
    err = assert_raises(ArgumentError) { c.cast([10]) }
    assert_equal "invalid value for config: 10 (key)", err.message
  end
  
  def test_cast_validates_input_is_an_array
    err = assert_raises(ArgumentError) { c.cast(1) }
    assert_equal "invalid value for config: 1 (key)", err.message
  end
end