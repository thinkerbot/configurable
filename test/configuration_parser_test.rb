require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configuration_parser'

class ConfigurationParserTest < Test::Unit::TestCase
  Option = ConfigurationParser::Option
  
  attr_reader :c
  
  def setup
    @c = ConfigurationParser.new
  end
  
  #
  # LONG_OPTION test
  #
  
  def test_LONG_OPTION
    r = ConfigurationParser::LONG_OPTION
    
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
    r = ConfigurationParser::SHORT_OPTION
    
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
    r = ConfigurationParser::ALT_SHORT_OPTION
    
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
    assert_equal '-o', ConfigurationParser.shortify("-o")
    assert_equal '-o', ConfigurationParser.shortify(:o)
  end
  
  def test_shortify_turns_option_into_short
    assert_equal "-o", ConfigurationParser.shortify("o")
    assert_equal "-a", ConfigurationParser.shortify("-a")
    assert_equal "-T", ConfigurationParser.shortify(:T)
  end
  
  def test_shortify_returns_nils
    assert_equal nil, ConfigurationParser.shortify(nil)
  end
  
  def test_shortify_raises_error_for_invalid_short
    e = assert_raise(ArgumentError) { ConfigurationParser.shortify("-long") }
    assert_equal "invalid short option: -long", e.message
    
    e = assert_raise(ArgumentError) { ConfigurationParser.shortify("-1") }
    assert_equal "invalid short option: -1", e.message
    
    e = assert_raise(ArgumentError) { ConfigurationParser.shortify("") }
    assert_equal "invalid short option: -", e.message
  end
  
  #
  # longify test
  #
  
  def test_longify_documentation
    assert_equal '--opt', ConfigurationParser.longify("--opt")
    assert_equal '--opt', ConfigurationParser.longify(:opt)
    assert_equal '--opt-ion', ConfigurationParser.longify(:opt_ion) 
  end
  
  def test_longify_turns_option_into_long
    assert_equal "--option", ConfigurationParser.longify("option")
    assert_equal "--an-option", ConfigurationParser.longify("--an-option")
    assert_equal "--T", ConfigurationParser.longify(:T)
  end
  
  def test_longify_returns_nils
    assert_equal nil, ConfigurationParser.longify(nil)
  end
  
  def test_longify_raises_error_for_invalid_long
    e = assert_raise(ArgumentError) { ConfigurationParser.longify("-long") }
    assert_equal "invalid long option: ---long", e.message
    
    e = assert_raise(ArgumentError) { ConfigurationParser.longify("1") }
    assert_equal "invalid long option: --1", e.message
    
    e = assert_raise(ArgumentError) { ConfigurationParser.longify("") }
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
    assert_equal expected, ConfigurationParser.nest('key' => 1, 'compound:key' => 2)
    
    options = [
      {'key' => {}},
      {'key' => {'overlap' => 'value'}}]
    assert options.include?(ConfigurationParser.nest('key' => {}, 'key:overlap' => 'value'))
  end
  
  #
  # register test
  #
  
  def test_register_adds_opt_to_options
    opt = Option.new(:key, 'value')
    c.register(opt)
    
    assert_equal [opt], c.options
  end
  
  def test_register_adds_opt_to_switches_by_switches
    opt = Option.new(:key, 'value', :long => 'long', :short => 's')
    c.register(opt)
    
    assert_equal({'--long' => opt, '-s' => opt}, c.switches)
  end
  
  def test_register_raises_error_for_conflicting_keys
    c.register(Option.new(:key, 'value'))
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:key, 'value')) }
    assert_equal "key is already set by a different option: key", e.message
  end
  
  def test_register_raises_error_for_conflicting_keys
    c.register(Option.new(:key, 'value'))
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:key, 'value')) }
    assert_equal "key is already set by a different option: key", e.message
  end
  
  def test_register_raises_error_for_conflicting_switches
    c.register(Option.new(:a, '', :long => 'key', :short => 'k'))
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:b, '', :long => 'key')) }
    assert_equal "switch is already mapped to a different option: --key", e.message
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:c, '', :short => 'k')) }
    assert_equal "switch is already mapped to a different option: -k", e.message
  end
  
  def test_register_does_not_raise_errors_for_registering_an_option_twice
    opt = Option.new(:a, '', :long => 'key', :short => 'k')
    c.register(opt)
    assert_nothing_raised { c.register(opt) }
  end
  
  #
  # on test
  #
  
  def test_on_adds_and_returns_option
    opt = c.on(:key, 'value')
    assert_equal [opt], c.options
  end
  
  def test_on_creates_Flag_option_with_flag_type
    opt = c.on(:key, true, :type => :flag)
    assert_equal ConfigurationParser::Flag, opt.class
  end
  
  def test_on_creates_Switch_option_with_switch_type
    opt = c.on(:key, true, :type => :switch)
    assert_equal ConfigurationParser::Switch, opt.class
  end
  
  #
  # parse test
  #
  
  def test_parse_adds_defaults_to_config
    c.on('opt', 'default')
    config, args = c.parse(["a", "b"])
    
    assert_equal({"opt" => "default"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option
    c.on('opt', 'default')
    config, args = c.parse(["a", "--opt", "value", "b"])
    
    assert_equal({"opt" => "value"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option_with_equals_syntax
    c.on('opt', 'default')
    config, args = c.parse(["a", "--opt=value", "b"])
    
    assert_equal({"opt" => "value"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option_with_empty_equals
    c.on('opt', 'default')
    config, args = c.parse(["a", "--opt=", "b"])
    
    assert_equal({"opt" => ""}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_syntax
    c.on('opt', 'default', :short => 'o')
    config, args = c.parse(["a", "-o", "value", "b"])
    
    assert_equal({"opt" => "value"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_equal_syntax
    c.on('opt', 'default', :short => 'o')
    config, args = c.parse(["a", "-o=value", "b"])
    
    assert_equal({"opt" => "value"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_empty_equals_syntax
    c.on('opt', 'default', :short => 'o')
    config, args = c.parse(["a", "-o=", "b"])
    
    assert_equal({"opt" => ""}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_alternate_short_syntax
    c.on('opt', 'default', :short => 'o')
    config, args = c.parse(["a", "-ovalue", "b"])
    
    assert_equal({"opt" => "value"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option_with_block
    c.on('opt', 'default') {|value| value.upcase }
    config, args = c.parse(["a", "--opt", "value", "b"])
    
    assert_equal({"opt" => "VALUE"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_block_recieves_default_values
    c.on('opt', 'default') {|value| value.upcase }
    config, args = c.parse(["a", "b"])
    
    assert_equal({"opt" => "DEFAULT"}, config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_raises_error_if_no_value_is_available
    c.on('opt', 'default')
    assert_raise(RuntimeError) { c.parse(["--opt"]) }
  end
  
  def test_parse_stops_parsing_on_option_break
    c.on('one', 'default')
    c.on('two', 'default')
    config, args = c.parse(["a", "--one", "1", "--", "--two", "2"])
    
    assert_equal({"one" => "1", "two" => "default"}, config)
    assert_equal(["a", "--two", "2"], args)
  end
  
  def test_parse_with_non_string_inputs
    c.on('opt', 'default')
    o = Object.new
    config, args = c.parse([o, 1, {}, "--opt", :sym, []])
    
    assert_equal({"opt" => :sym}, config)
    assert_equal([o, 1, {},[]], args)
  end
  
  #
  # parse flag test
  #
  
  def test_parse_flag
    c.on('opt', false, :type => :flag)
    config, args = c.parse(["a", "--opt", "b"])
    
    assert_equal({"opt" => true}, config)
    assert_equal(["a", "b"], args)
  end
  
  #
  # parse switch test
  #
  
  def test_parse_switch
    c.on('opt', true, :type => :switch)
    config, args = c.parse(["a", "--opt", "b"])
    
    assert_equal({"opt" => true}, config)
    assert_equal(["a", "b"], args)
    
    config, args = c.parse(["a", "--no-opt", "b"])
    
    assert_equal({"opt" => false}, config)
    assert_equal(["a", "b"], args)
  end
end