require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_classes'

class ListConfigTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
  
  attr_reader :list
  
  def setup
    @list = ListConfig.new(:key)
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_each_value_of_the_input
    list = ListConfig.new(:key, :type => StringType.new)
    
    input = [1,'2',3]
    output = list.cast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
  
  #
  # uncast test
  #
  
  def test_uncast_uncasts_each_value_of_the_input
    list = ListConfig.new(:key, :type => StringType.new)
    
    input = [1,'2',3]
    output = list.uncast(input)
    
    assert_equal ['1','2','3'], output
    assert input.object_id != output.object_id
  end
end