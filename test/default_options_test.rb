require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class DefaultOptionsTest < Test::Unit::TestCase 
  #
  # DEFAULT_OPTIONS test
  #
  
  class ReferenceClass
    include Configurable
  end
  
  class DefaultOptionsClass
    include Configurable
    DEFAULT_OPTIONS = DEFAULT_OPTIONS.dup
    DEFAULT_OPTIONS[:key] = 'value'
  end
  
  def test_default_attributes_may_be_overridden
    assert_equal({}, ReferenceClass::DEFAULT_OPTIONS[:key])
    assert_equal('value', DefaultOptionsClass::DEFAULT_OPTIONS[:key])
  end
  
end