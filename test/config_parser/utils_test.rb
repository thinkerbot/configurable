require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'config_parser/utils'

class UtilsTest < Test::Unit::TestCase
  include ConfigParser::Utils

  attr_reader :config
  
  def setup
    @config = {}
  end
  
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
    assert_equal '-o', shortify("-o")
    assert_equal '-o', shortify(:o)
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
    assert_equal '--opt', longify("--opt")
    assert_equal '--opt', longify(:opt)
    assert_equal '--opt-ion', longify(:opt_ion) 
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
  # setup_option test
  #
  
  def test_setup_option_infers_long_and_argname
    options = {}
    setup_option(:key, options)
    assert_equal({:long => '--key', :arg_name => 'KEY'}, options)
  end
  
  def test_setup_option_does_not_overwrite_existing_long_and_argname
    options = {:long => 'long', :arg_name => 'arg'}
    setup_option(:key, options)
    assert_equal({:long => 'long', :arg_name => 'arg'}, options)
  end
  
  def test_setup_option_block_sets_value_in_config
    setup_option(:key).call('value')
    assert_equal({:key => 'value'}, config)
  end
  
  #
  # setup_flag test
  #
  
  def test_setup_flag_infers_long_but_not_argname
    options = {}
    setup_flag(:key, true, options)
    assert_equal({:long => '--key'}, options)
  end
  
  def test_setup_flag_does_not_overwrite_existing_long
    options = {:long => 'long'}
    setup_flag(:key, true, options)
    assert_equal({:long => 'long'}, options)
  end
  
  def test_setup_flag_block_sets_not_default_value
    setup_flag(:a, true).call
    setup_flag(:b, false).call
    
    assert_equal({:a => false, :b => true}, config)
  end
  
  #
  # setup_switch test
  #
  
  def test_setup_switch_infers_long_but_not_argname
    options = {}
    setup_switch(:key, true, options)
    assert_equal({:long => '--[no-]key'}, options)
  end
  
  def test_setup_switch_uses_existing_long_to_make_switch_key
    options = {:long => 'long'}
    setup_switch(:key, true, options)
    assert_equal({:long => '--[no-]long'}, options)
  end
  
  def test_setup_switch_uses_valid_switch_key
    options = {:long => '--[no-]long'}
    setup_switch(:key, true, options)
    assert_equal({:long => '--[no-]long'}, options)
  end
  
  def test_setup_switch_block_sets_not_default_value_if_true
    setup_switch(:a, true).call(true)
    setup_switch(:b, false).call(true)
    
    assert_equal({:a => false, :b => true}, config)
  end
  
  def test_setup_switch_block_sets_default_value_if_false
    setup_switch(:a, true).call(false)
    setup_switch(:b, false).call(false)
    
    assert_equal({:a => true, :b => false}, config)
  end
  
  #
  # setup_list test
  #
  
  def test_setup_list_infers_long_and_argname
    options = {}
    setup_list(:key, options)
    assert_equal({:long => '--key', :arg_name => 'KEY'}, options)
  end
  
  def test_setup_list_infers_split_argname_with_split
    options = {:split => ','}
    setup_list(:key, options)
    assert_equal({:long => '--key', :arg_name => 'A,B,C', :split => ','}, options)
  end
  
  def test_setup_list_does_not_overwrite_existing_long_and_argname
    options = {:long => 'long', :arg_name => 'argname'}
    setup_list(:key, options)
    assert_equal({:long => 'long', :arg_name => 'argname'}, options)
  end
  
  def test_setup_list_block_concatenates_values
    block = setup_list(:key)
    block.call(1)
    block.call('a,b,c')
    block.call([3])
    
    assert_equal({:key => [1, 'a,b,c', [3]]}, config)
  end
  
  def test_setup_list_block_splits_values_along_split
    block = setup_list(:key, :split => ',')
    block.call('a,b,c')
    block.call('d,e')

    assert_equal({:key => %w{a b c d e} }, config)
  end
  
  def test_setup_list_block_raises_error_for_assignments_past_n
    block = setup_list(:key, :n => 2)
    block.call(1)
    block.call(2)
    
    e = assert_raise(RuntimeError) { block.call(3) }
    assert_equal "too many assignments: :key", e.message 
  end
end