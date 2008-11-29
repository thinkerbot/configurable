require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'config_parser'

class ConfigParserTest < Test::Unit::TestCase
  Option = ConfigParser::Option
  
  attr_reader :c
  
  def setup
    @c = ConfigParser.new
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
    assert_equal ConfigParser::Flag, opt.class
  end
  
  def test_on_creates_Switch_option_with_switch_type
    opt = c.on(:key, true, :type => :switch)
    assert_equal ConfigParser::Switch, opt.class
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