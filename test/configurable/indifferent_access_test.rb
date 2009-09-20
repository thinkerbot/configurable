require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/indifferent_access'

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
  
  #
  # dup test
  #
  
  def test_duplicates_use_indifferent_access
    hash = {}.extend Configurable::IndifferentAccess
    assert hash.dup.kind_of?(Configurable::IndifferentAccess)
  end
end