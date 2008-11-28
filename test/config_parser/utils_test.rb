require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'config_parser/option'

class UtilsTest < Test::Unit::TestCase
  include ConfigParser::Utils
  
  #
  # LONG_OPTION test
  #
  
  def test_LONG_OPTION
    r = LONG_OPTION
    
    assert "--long-option" =~ r
    assert_equal "--long-option", $1
    assert_equal nil, $3
    
    assert "--long-option=value" =~ r
    assert_equal "--long-option", $1
    assert_equal "value", $3
    
    assert "--nested:long-option=value" =~ r
    assert_equal "--nested:long-option", $1
    assert_equal "value", $3
    
    assert "--long-option=value=with=equals" =~ r
    assert_equal "--long-option", $1
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
    r = SHORT_OPTION
    
    assert "-o" =~ r
    assert_equal "-o", $1
    assert_equal nil, $3
    
    assert "-ovalue" =~ r
    assert_equal "-o", $1
    assert_equal "value", $3
    
    assert "-o=value" =~ r
    assert_equal "-o", $1
    assert_equal "value", $3
    
    assert "-o=value=with=equals" =~ r
    assert_equal "-o", $1
    assert_equal "value=with=equals", $3
    
    # non-matching
    assert "arg" !~ r
    assert "--o" !~ r
    assert "--" !~ r
    assert "-." !~ r
    assert "-1" !~ r
    assert "-=value" !~ r
  end
  
  #
  # shortify test
  #
  
  def test_shortify_documentation
    assert_equal '-o', ConfigParser::Utils.shortify("-o")
    assert_equal '-o', ConfigParser::Utils.shortify(:o)
  end
  
  def test_shortify_turns_option_into_short
    assert_equal "-o", shortify("o")
    assert_equal "-a", shortify("-a")
    assert_equal "-T", shortify(:T)
  end
  
  def test_shortify_returns_nils
    assert_equal nil, shortify(nil)
  end
  
  def test_shortify_raises_error_for_invalid_short
    e = assert_raise(ArgumentError) { shortify("-long") }
    assert_equal "invalid short option: -long", e.message
    
    e = assert_raise(ArgumentError) { shortify("-1") }
    assert_equal "invalid short option: -1", e.message
    
    e = assert_raise(ArgumentError) { shortify("") }
    assert_equal "invalid short option: -", e.message
  end
  
  #
  # longify test
  #
  
  def test_longify_documentation
    assert_equal '--opt', ConfigParser::Utils.longify("--opt")
    assert_equal '--opt', ConfigParser::Utils.longify(:opt)
    assert_equal '--opt-ion', ConfigParser::Utils.longify(:opt_ion) 
  end
  
  def test_longify_turns_option_into_long
    assert_equal "--option", longify("option")
    assert_equal "--an-option", longify("--an-option")
    assert_equal "--T", longify(:T)
  end
  
  def test_longify_returns_nils
    assert_equal nil, longify(nil)
  end
  
  def test_longify_raises_error_for_invalid_long
    e = assert_raise(ArgumentError) { longify("-long") }
    assert_equal "invalid long option: ---long", e.message
    
    e = assert_raise(ArgumentError) { longify("1") }
    assert_equal "invalid long option: --1", e.message
    
    e = assert_raise(ArgumentError) { longify("") }
    assert_equal "invalid long option: --", e.message
  end
end