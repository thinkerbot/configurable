require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ListTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
  
  attr_reader :config
  
  def setup
    @config = List.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    config = List.new(:key, :type => IntegerType.new)
    
    input = [1,'2',3]
    output = config.cast(input)
    
    assert_equal [1,2,3], output
    assert input.object_id != output.object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_each_value_of_the_input
    config = List.new(:key, :type => IntegerType.new)
    
    input = [1,'2',3]
    output = config.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
end