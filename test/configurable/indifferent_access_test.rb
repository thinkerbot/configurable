require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable'

class IndifferentAccessTest < Test::Unit::TestCase

  def test_indifferent_access_treats_strings_as_symbols_in_AGET
    hash = {:sym => 'sym'}.extend Configurable::IndifferentAccess
    
    assert_equal 'sym', hash[:sym]
    assert_equal 'sym', hash['sym']
  end
  
  def test_indifferent_access_treats_strings_as_symbols_in_ASET
    hash = {}.extend Configurable::IndifferentAccess
    
    hash[:sym] = 'value'
    assert_equal({:sym => 'value'}, hash)
    
    hash['sym'] = 'new value'
    assert_equal({:sym => 'new value'}, hash)
  end
  
end