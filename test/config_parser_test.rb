require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'config_parser'

class ConfigParserTest < Test::Unit::TestCase

  #
  # LONG_OPTION test
  #
  
  def test_LONG_OPTION
    r = ConfigParser::LONG_OPTION
    
    assert "--long-option" =~ r
    assert_equal "long-option", $1
    assert_equal nil, $3
    
    assert "--long-option=value" =~ r
    assert_equal "long-option", $1
    assert_equal "value", $3
    
    assert "--nested:long-option=value" =~ r
    assert_equal "nested:long-option", $1
    assert_equal "value", $3
    
    assert "--long-option=value=with=equals" =~ r
    assert_equal "long-option", $1
    assert_equal "value=with=equals", $3
    
    # non-matching
    assert "arg" !~ r
    assert "-o" !~ r
    assert "--" !~ r
    assert "---" !~ r
    assert "--." !~ r
    assert "--1" !~ r
    assert "--=value" !~ r
  end
  
  #
  # SHORT_OPTION test
  #
  
  def test_SHORT_OPTION
    r = ConfigParser::SHORT_OPTION
    
    assert "-o" =~ r
    assert_equal "o", $1
    assert_equal nil, $3
    
    assert "-ovalue" =~ r
    assert_equal "o", $1
    assert_equal "value", $3
    
    assert "-o=value" =~ r
    assert_equal "o", $1
    assert_equal "value", $3
    
    assert "-o=value=with=equals" =~ r
    assert_equal "o", $1
    assert_equal "value=with=equals", $3
    
    # non-matching
    assert "arg" !~ r
    assert "--o" !~ r
    assert "--" !~ r
    assert "-." !~ r
    assert "-1" !~ r
    assert "-=value" !~ r
  end
end