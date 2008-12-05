require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'config_parser'

class ConfigParserTest < Test::Unit::TestCase
  Option = ConfigParser::Option
  
  attr_reader :c
  
  def setup
    @c = ConfigParser.new
  end
  
  #
  # ConfigParser.nest test
  #
  
  def test_nest_documentation
    expected = {
      'key' => 1,
      'compound' => {'key' => 2}
    }
    assert_equal expected, ConfigParser.nest('key' => 1, 'compound:key' => 2)
    
    options = [
      {'key' => {}},
      {'key' => {'overlap' => 'value'}}]
    assert options.include?(ConfigParser.nest('key' => {}, 'key:overlap' => 'value'))
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = ConfigParser.new
    assert_equal({}, c.switches)
    assert_equal({}, c.config)
    assert_equal({}, c.default_config)
  end
  
  #
  # register test
  #
  
  def test_register_adds_opt_to_options
    opt = Option.new
    c.register(opt)
    
    assert_equal [opt], c.options
  end
  
  def test_register_adds_opt_to_switches_by_switches
    opt = Option.new(:long => 'long', :short => 's')
    c.register(opt)
    
    assert_equal({'--long' => opt, '-s' => opt}, c.switches)
  end
  
  def test_register_raises_error_for_conflicting_switches
    c.register(Option.new(:long => 'key', :short => 'k'))
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:long => 'key')) }
    assert_equal "switch is already mapped to a different option: --key", e.message
    
    e = assert_raise(ArgumentError) { c.register(Option.new(:short => 'k')) }
    assert_equal "switch is already mapped to a different option: -k", e.message
  end
  
  def test_register_does_not_raise_errors_for_registering_an_option_twice
    opt = Option.new(:long => 'key', :short => 'k')
    c.register(opt)
    assert_nothing_raised { c.register(opt) }
  end
  
  #
  # on test
  #
  
  def test_on_adds_and_returns_option
    opt = c.on
    assert_equal [opt], c.options
  end
  
  def test_on_sets_block_in_option
    b = lambda {}
    opt = c.on(&b)
    assert_equal b, opt.block
  end
  
  def test_on_uses_a_trailing_hash_for_options
    opt = c.on("-s", :long => 'long')
    assert_equal '-s', opt.short
    assert_equal '--long', opt.long
  end
  
  def test_on_parses_option_attributes
    opt = c.on("-s", "--long ARG_NAME", "Description for the Option")
    assert_equal '-s', opt.short
    assert_equal '--long', opt.long
    assert_equal 'ARG_NAME', opt.arg_name
    assert_equal 'Description for the Option', opt.desc
    
    opt = c.on("   some description   ", "-o", "--key   argument name    ")
    assert_equal '-o', opt.short
    assert_equal '--key', opt.long
    assert_equal 'argument name', opt.arg_name
    assert_equal 'some description', opt.desc
    
    opt = c.on("--compound-long")
    assert_equal nil, opt.short
    assert_equal '--compound-long', opt.long
    assert_equal nil, opt.arg_name
    assert_equal nil, opt.desc
  end
  
  def test_on_raises_error_for_conflicting_option_attributes
    e = assert_raise(ArgumentError) { c.on('--long', '--alt') }
    assert_equal "conflicting long options: [--long, --alt]", e.message
    
    e = assert_raise(ArgumentError) { c.on('-s', '-o') }
    assert_equal "conflicting short options: [-s, -o]", e.message
    
    e = assert_raise(ArgumentError) { c.on('desc one', 'desc two') }
    assert_equal "conflicting desc options: [desc one, desc two]", e.message
  end
  
  def test_on_creates_Switch_option_with_switch_long
    opt = c.on('--[no-]switch')
    assert_equal ConfigParser::Switch, opt.class
  end
  
  #
  # define test
  #
  
  def test_define_adds_and_returns_an_option
    opt = c.define(:key)
    assert_equal [opt], c.options
  end
  
  def test_define_adds_default_value_to_default_config
    c.define(:key, 'value')
    assert_equal({:key => 'value'}, c.default_config)
  end
  
  def test_define_raises_error_for_conflicting_keys
    c.define(:key)
    
    e = assert_raise(ArgumentError) { c.define(:key) }
    assert_equal "already set by a different option: :key", e.message
  end
  
  #
  # parse test
  #
  
  def test_parse_for_simple_option
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "--opt", "value", "b"])
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option_with_equals_syntax
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "--opt=value", "b"])
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_for_simple_option_with_empty_equals
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "--opt=", "b"])
    
    assert_equal("", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_syntax
    value_in_block = nil
    c.on('-o VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "-o", "value", "b"])
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_equal_syntax
    value_in_block = nil
    c.on('-o VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "-o=value", "b"])
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_short_empty_equals_syntax
    value_in_block = nil
    c.on('-o VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "-o=", "b"])
    
    assert_equal("", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_with_alternate_short_syntax
    value_in_block = nil
    c.on('-o VALUE') {|value| value_in_block = value}
    
    args = c.parse(["a", "-ovalue", "b"])
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_raises_error_if_no_value_is_available
    c.on('--opt VALUE')
    assert_raise(RuntimeError) { c.parse(["--opt"]) }
  end
  
  def test_parse_stops_parsing_on_option_break
    values = []
    c.on('--one VALUE') {|value| values << value }
    c.on('--two VALUE') {|value| values << value }
    
    args = c.parse(["a", "--one", "1", "--", "--two", "2"])
    
    assert_equal(["1"], values)
    assert_equal(["a", "--two", "2"], args)
  end
  
  def test_parse_with_non_string_inputs
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    o = Object.new
    args = c.parse([o, 1, {}, "--opt", :sym, []])
    
    assert_equal(:sym, value_in_block)
    assert_equal([o, 1, {},[]], args)
  end
  
  def test_parse_does_not_modify_argv
    c.on('--opt VALUE')
    
    argv = ["a", "--opt=value", "b"]
    args = c.parse(argv)
    
    assert_equal(["a", "--opt=value", "b"], argv)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_bang_removes_parsed_args_from_argv
    c.on('--opt VALUE')
    
    argv = ["a", "--opt=value", "b"]
    c.parse!(argv)
    
    assert_equal(["a", "b"], argv)
  end
  
  #
  # parse using config test
  #
  
  def test_parse_adds_defaults_to_config
    c.define('opt', 'default')
    args = c.parse(["a", "b"])
    
    assert_equal({"opt" => "default"}, c.config)
    assert_equal(["a", "b"], args)
  end

  def test_parse_sets_config_values
    c.define('opt', 'default')
    args = c.parse(["a", "--opt", "value", "b"])
    
    assert_equal({"opt" => "value"}, c.config)
    assert_equal(["a", "b"], args)
  end
  
  #
  # parse flag test
  #
  
  def test_parse_flag_calls_block_for_switch
    was_in_block = nil
    c.on('--opt') do |*args| 
      assert args.empty?
      was_in_block = true
    end

    c.parse(["a", "--opt", "b"])
    assert was_in_block
  end
  
  def test_parse_flag_does_not_call_block_without_switch
    was_in_block = nil
    c.on('--opt') { was_in_block = true }

    c.parse(["a", "b"])
    assert_equal nil, was_in_block
  end
  
  #
  # parse switch test
  #
  
  def test_parse_switch_passes_true_for_switch
    value_in_block = nil
    c.on('--[no-]opt') {|value| value_in_block = value}

    c.parse(["a", "--opt", "b"])
    assert_equal(true, value_in_block)
  end
  
  def test_parse_switch_passes_true_for_short
    value_in_block = nil
    c.on('--[no-]opt', '-o') {|value| value_in_block = value}

    c.parse(["a", "-o", "b"])
    assert_equal(true, value_in_block)
  end
  
  def test_parse_switch_passes_false_for_no_switch
    value_in_block = nil
    c.on('--[no-]opt') {|value| value_in_block = value}
   
    c.parse(["a", "--no-opt", "b"])
    assert_equal(false, value_in_block)
  end
  
  def test_parse_switch_does_not_call_block_without_switch
    was_in_block = nil
    c.on('--[no-]opt') { was_in_block = true }

    c.parse(["a", "b"])
    assert_equal nil, was_in_block
  end
  
  def test_switch_raises_error_when_arg_name_is_specified
    e = assert_raise(ArgumentError) { c.on('--[no-]opt VALUE') }
    assert_equal "arg_name specified for switch: VALUE", e.message
  end
  
  #
  # parse list test
  #
  
  def test_parse_list
    c.define('opt', [], :type => :list)
    args = c.parse(["a", "--opt", "one", "--opt", "two", "--opt", "three", "b"])
    
    assert_equal({"opt" => ["one", "two", "three"]}, c.config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_list_with_split
    c.define('opt', [], :type => :list, :split => ',')
    args = c.parse(["a", "--opt", "one,two", "--opt", "three", "b"])
    
    assert_equal({"opt" => ["one", "two", "three"]}, c.config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_list_with_limit_raises_error_for_too_many_entries
    c.define('opt', [], :type => :list, :n => 1)
    e = assert_raise(RuntimeError) { c.parse(["a", "--opt", "one", "--opt", "three", "b"]) }
    assert_equal "too many assignments: \"opt\"", e.message
  end
  
  #
  # to_s test
  #
  
  def test_to_s
    c.on('--opt OPT', '-o', 'desc')
    c.separator "specials:"
    c.define('switch', true, :type => :switch)
    c.define('flag', true, :type => :flag)
    c.define('list', true, :type => :list, :long => '--list', :split => ',')
    
    expected = %Q{
    -o, --opt OPT                    desc
specials:
        --[no-]switch
        --flag
        --list A,B,C
}
    assert_equal expected, "\n" + c.to_s
  end
end