require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configuration_parser/utils'

class UtilsTest < Test::Unit::TestCase
  include ConfigurationParser::Utils
  
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
    
    assert "--long-option=" =~ r
    assert_equal "--long-option", $1
    assert_equal "", $3
    
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
    assert_equal nil, $4
    
    assert "-o=value" =~ r
    assert_equal "-o", $1
    assert_equal "value", $4
    
    assert "-o=" =~ r
    assert_equal "-o", $1
    assert_equal "", $4
    
    assert "-n:l:o=value" =~ r
    assert_equal "-n:l:o", $1
    assert_equal "value", $4
    
    assert "-o=value=with=equals" =~ r
    assert_equal "-o", $1
    assert_equal "value=with=equals", $4
    
    # non-matching
    assert "arg" !~ r
    assert "--o" !~ r
    assert "--" !~ r
    assert "-." !~ r
    assert "-1" !~ r
    assert "-=value" !~ r
    assert "-n:long" !~ r
  end
  
  #
  # ALT_SHORT_OPTION test
  #
  
  def test_ALT_SHORT_OPTION
    r = ALT_SHORT_OPTION
    
    assert "-ovalue" =~ r
    assert_equal "-o", $1
    assert_equal "value", $3

    assert "-n:l:ovalue" =~ r
    assert_equal "-n:l:o", $1
    assert_equal "value", $3
    
    # non-matching
    assert "arg" !~ r
    assert "--o" !~ r
    assert "--" !~ r
    assert "-." !~ r
    assert "-1" !~ r
    assert "-=value" !~ r
    assert "-o" !~ r
  end
  
  #
  # shortify test
  #
  
  def test_shortify_documentation
    assert_equal '-o', ConfigurationParser::Utils.shortify("-o")
    assert_equal '-o', ConfigurationParser::Utils.shortify(:o)
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
    assert_equal '--opt', ConfigurationParser::Utils.longify("--opt")
    assert_equal '--opt', ConfigurationParser::Utils.longify(:opt)
    assert_equal '--opt-ion', ConfigurationParser::Utils.longify(:opt_ion) 
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
  
  #
  # nest test
  #
  
  def test_nest_documentation
    expected = {
      'key' => 1,
      'compound' => {'key' => 2}
    }
    assert_equal expected, nest('key' => 1, 'compound:key' => 2)
    
    options = [
      {'key' => {}},
      {'key' => {'overlap' => 'value'}}]
    assert options.include?(nest('key' => {}, 'key:overlap' => 'value'))
  end
end