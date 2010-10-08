require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class SelectTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  
  attr_reader :c
  
  def setup
    @c = Select.new(:key, :options => [1,2,3])
  end
  
  #
  # cast test
  #
  
  def test_cast_validates_each_input_value_is_in_options
    assert_equal 1, c.cast(1)
    
    err = assert_raises(ArgumentError) { c.cast(10) }
    assert_equal "invalid value for config: 10 (key)", err.message
  end
end