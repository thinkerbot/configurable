require File.expand_path('../../test_helper', __FILE__)
require 'config_parser/switch'

class SwitchTest < Test::Unit::TestCase
  Switch = ConfigParser::Switch
  
  def test_parse_raises_error_if_value_is_provided
    opt = Switch.new :long => 'switch'
    
    e = assert_raises(RuntimeError) { opt.parse('--switch', 'value', []) }
    assert_equal "value specified for switch: --switch", e.message
  end
end