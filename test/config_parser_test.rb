require  File.expand_path('../test_helper', __FILE__)
require 'config_parser'
require 'configurable'

class ConfigParserTest < Test::Unit::TestCase
  Option = ConfigParser::Option
  Config = Configurable::Config
  Nest = Configurable::Configs::Nest
  ConfigHash = Configurable::ConfigHash
  
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
  # documentation test
  #
  
  class ConfigClass
    include Configurable

    config :long, 'default', :short => 's'  # a standard option
    config :switch, true                    # a switch
    config :flag, false                     # a flag
  end
  
  def test_documentation
    opts = {}
    parser = ConfigParser.new do |psr|
      psr.on "-s", "--long LONG", "a standard option" do |value|
        opts[:long] = value
      end
    
      psr.on "--[no-]switch", "a switch" do |value|
        opts[:switch] = value
      end
  
      psr.on "--flag", "a flag" do
        # note: no value is parsed; the block 
        # only executes if the flag is found
        opts[:flag] = true
      end
    end
  
    assert_equal ['a', 'b', 'c'], parser.parse("a b --long arg --switch --flag c")
    assert_equal({:long => 'arg', :switch => true, :flag => true}, opts)
  
    psr = ConfigParser.new
    psr.define(:key, 'default', :desc => 'a standard option')
  
    assert_equal ['a', 'b', 'c'], psr.parse('a b --key option c')
    assert_equal({:key => 'option'}, psr.config)
  
    assert_equal ['a', 'b', 'c'], psr.parse('a b c')
    assert_equal({:key => 'default'}, psr.config)
  
    psr = ConfigParser.new
    psr.add(ConfigClass.configurations)
  
    assert_equal ['a', 'b', 'c'], psr.parse("a b --long arg --switch --flag c")
    assert_equal({:long => 'arg', :switch => true, :flag => true}, psr.config)
  
    assert_equal ['a', 'b', 'c'], psr.parse("a b --long=arg --no-switch c")
    assert_equal({:long => 'arg', :switch => false, :flag => false}, psr.config)
  
    assert_equal ['a', 'b', 'c'], psr.parse("a b -sarg c")
    assert_equal({:long => 'arg', :switch => true, :flag => false}, psr.config)
  
    expected = %q{
configurations:
        --flag                       a flag
    -s, --long LONG                  a standard option
        --[no-]switch                a switch
}
    assert_equal expected, "\nconfigurations:\n#{psr.to_s}"
    
    ####
    psr = ConfigParser.new

    e = assert_raises(ArgumentError) do
      psr.on("--delay N", 
      Float,
      "Delay N seconds before executing")
    end
    assert_equal "conflicting desc options: [Float, \"Delay N seconds before executing\"]", e.message

    psr.on("--delay N", "Delay N seconds before executing") do |value|
      value.to_f
    end

    e = assert_raises(ArgumentError) do
      psr.on("-i", "--inplace [EXTENSION]",
      "Edit ARGV files in place",
      "  (make backup if EXTENSION supplied)")
    end
    assert_equal "conflicting desc options: [\"Edit ARGV files in place\", \"  (make backup if EXTENSION supplied)\"]", e.message

    # correct
    psr.on("-i", "--inplace EXTENSION", 
    "Edit ARGV files in place\n  (make backup if EXTENSION supplied)")
  end
  
  #
  # bind test
  #
  
  def test_bind_documentation
    psr = ConfigParser.bind
    psr.define('a', 'default')
    psr.define('b', 'default')
  
    psr.parse %w{--a value}
    assert_equal({"a" => "value"}, psr.config)
  
    psr.parse %w{--b value}
    assert_equal({"a" => "value", "b" => "value"}, psr.config)
  end
  
  def test_bind_yields_self_to_block_if_given
    parser = nil
    c = ConfigParser.bind({}) do |psr|
      parser = psr
    end
    
    assert_equal c, parser
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = ConfigParser.new
    assert_equal({}, c.switches)
    assert_equal({}, c.config)
    assert_equal({}, c.defaults)
  end
  
  def test_initialize_sets_config
    config = {}
    c = ConfigParser.new(config)
    assert_equal config.object_id, c.config.object_id
  end
  
  #
  # AGET test
  #
  
  def test_AGET_gets_config_value
    assert_equal(nil, c[:key])
    c.config[:key] = 'value'
    assert_equal('value', c[:key])
  end
  
  #
  # ASET test
  #
  
  def test_ASET_sets_config_value
    assert_equal({}, c.config)
    c[:key] = 'value'
    assert_equal({:key => 'value'}, c.config)
  end
  
  #
  # nested_config test
  #
  
  def test_nested_config_returns_the_nested_version_of_config
    c.config['nest:key'] = 'value'
    assert_equal({'nest' => {'key' => 'value'}}, c.nested_config)
  end
  
  #
  # register test
  #
  
  def test_register_adds_opt_to_registry
    opt = Option.new
    c.register(opt)
    
    assert_equal [opt], c.registry
  end
  
  def test_register_adds_opt_to_switches_by_switches
    opt = Option.new(:long => 'long', :short => 's')
    c.register(opt)
    
    assert_equal({'--long' => opt, '-s' => opt}, c.switches)
  end
  
  def test_register_raises_error_for_conflicting_switches
    c.register(Option.new(:long => 'key', :short => 'k'))
    
    e = assert_raises(ArgumentError) { c.register(Option.new(:long => 'key')) }
    assert_equal "switch is already mapped to a different option: --key", e.message
    
    e = assert_raises(ArgumentError) { c.register(Option.new(:short => 'k')) }
    assert_equal "switch is already mapped to a different option: -k", e.message
  end
  
  def test_register_removes_conflicting_options_on_override
    o1 = Option.new(:long => 'key')
    o2 = Option.new(:short => 'k')
    o3 = Option.new(:long => 'non-conflict', :short => 'n')
    
    c.register(o1)
    c.register(o2)
    c.register(o3)
        
    assert_equal [o1, o2, o3], c.registry
    assert_equal({
      '--key' => o1,
      '-k' => o2,
      '--non-conflict' => o3,
      '-n' => o3
    }, c.switches)
    
    o4 = Option.new(:long => 'key', :short => 'k')
    c.register(o4, true)
    
    assert_equal [o3, o4], c.registry
    assert_equal({
      '--key' => o4,
      '-k' => o4,
      '--non-conflict' => o3,
      '-n' => o3
    }, c.switches)
  end
  
  def test_register_does_not_raises_errors_for_registering_an_option_twice
    opt = Option.new(:long => 'key', :short => 'k')
    c.register(opt)
    c.register(opt)
  end
  
  #
  # on test
  #
  
  def test_on_adds_and_returns_option
    opt = c.on
    assert_equal [opt], c.registry
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
    
    opt = c.on("--compound-long")
    assert_equal nil, opt.short
    assert_equal '--compound-long', opt.long
    assert_equal nil, opt.arg_name
    assert_equal nil, opt.desc
  end
  
  def test_on_raises_error_for_conflicting_option_attributes
    e = assert_raises(ArgumentError) { c.on('--long', '--alt') }
    assert_equal "conflicting long options: [\"--long\", \"--alt\"]", e.message
    
    e = assert_raises(ArgumentError) { c.on('-s', '-o') }
    assert_equal "conflicting short options: [\"-s\", \"-o\"]", e.message
    
    e = assert_raises(ArgumentError) { c.on('desc one', 'desc two') }
    assert_equal "conflicting desc options: [\"desc one\", \"desc two\"]", e.message
  end
  
  def test_on_creates_Switch_option_with_switch_long
    opt = c.on('--[no-]switch')
    assert_equal ConfigParser::Switch, opt.class
  end
  
  #
  # on! test
  #
  
  def test_on_bang_overrides_conflicting_options
    o1 = c.on! "--key"
    o2 = c.on! "-k"
    o3 = c.on! "-n", "--non-conflict"
    
    assert_equal [o1, o2, o3], c.registry
    assert_equal({
      '--key' => o1,
      '-k' => o2,
      '--non-conflict' => o3,
      '-n' => o3
    }, c.switches)
    
    o4 = c.on! "-k", "--key"
    
    assert_equal [o3, o4], c.registry
    assert_equal({
      '--key' => o4,
      '-k' => o4,
      '--non-conflict' => o3,
      '-n' => o3
    }, c.switches)
  end
  
  #
  # define test
  #
  
  module SpecialType
    def setup_special(key, default_value, attributes)
      # modify attributes if necessary
      attributes[:long] = "--#{key}"
      attributes[:arg_name] = 'ARG_NAME'

      # return a block handling the input
      lambda {|input| config[key] = input.reverse }
    end
  end
  
  def test_define_documentation
    psr = ConfigParser.new
    psr.define(:one, 'default')
    psr.define(:two, 'default', :long => '--long', :short => '-s')
  
    psr.parse("--one one --long two")
    assert_equal({:one => 'one', :two => 'two'}, psr.config)
  
    psr = ConfigParser.new
    psr.define(:flag, false, :type => :flag)
    psr.define(:switch, false, :type => :switch)
    psr.define(:list, [], :type => :list)
  
    psr.parse("--flag --switch --list one --list two --list three")
    assert_equal({:flag => true, :switch => true, :list => ['one', 'two', 'three']}, psr.config)
  
    psr = ConfigParser.new.extend SpecialType
    psr.define(:opt, false, :type => :special)
  
    psr.parse("--opt value")
    assert_equal({:opt => 'eulav'}, psr.config)
  end
  
  def test_define_adds_and_returns_an_option
    opt = c.define(:key)
    assert_equal [opt], c.registry
  end
  
  def test_define_adds_default_value_to_defaults
    c.define(:key, 'value')
    assert_equal({:key => 'value'}, c.defaults)
  end
  
  def test_define_does_not_add_or_generate_an_option_if_type_is_hidden
    assert_equal nil, c.define(:key, 'value', :type => :hidden)
    assert_equal [], c.registry
  end
  
  def test_define_does_not_add_a_long_option_if_nil
    opt = c.define(:key, 'value', :long => nil, :short => :s)
    assert_equal nil, opt.long
  end
  
  def test_define_raises_error_for_conflicting_keys
    c.define(:key)
    
    e = assert_raises(ArgumentError) { c.define(:key) }
    assert_equal "already set by a different option: :key", e.message
  end
  
  def test_define_does_not_modify_input_attributes
    attrs = {}
    c.define(:key, 'value', attrs)
    assert_equal({}, attrs)
  end
  
  #
  # add test
  #

  class NestClass
    include Configurable
    nest :nest do
      config :key, 'value'
    end
  end

  def test_add_documentation
    psr = ConfigParser.new
    psr.add(NestClass.configurations)
    psr.parse('--nest:key value')
    
    assert_equal({'nest:key' => 'value'}, psr.config)
    assert_equal({'nest' => {'key' => 'value'}}, psr.nested_config)
  end
  
  def test_add_nests_delegates_according_to_nest
    delegates = {
      :one => Config.new(:one, 'one', :one, :one=),
      :two => Config.new(:two, 'two', :two, :two=),
    }
    
    c.add(delegates, "nest")
    assert_equal({"nest:one" => 'one', "nest:two" => 'two'}, c.defaults)
  end
  
  def test_add_nests_switches_properly
    delegates = {
      :one => Config.new(:one, 'one', :one, :one=, :type => :switch)
    }
    
    c.add(delegates, "nest")
    assert_equal(["--nest:one", "--nest:no-one"], c.switches.keys)
  end
  
  class ConfigurableClass
    include Configurable
    config :one, 'one'
    config :two, 'two'
  end
  
  def test_add_adds_nest_delegates_normally
    delegates = {
      :one => Nest.new(:one, ConfigurableClass, :one, :one=),
      :two => Config.new(:two, 'two', :two, :two=)
    }
    
    c.add(delegates)
    assert_equal({:two => 'two', :one => {:one => 'one', :two => 'two'}}, c.defaults)
  end
  
  def test_add_recusively_adds_delegates_from_nest_delegates_with_nest_type
    delegates = {
      :one => Nest.new(:one, ConfigurableClass, :one, :one=, :type => :nest),
      :two => Config.new(:two, 'two', :two, :two=)
    }
    
    c.add(delegates)
    assert_equal({:two => 'two', "one:one" => 'one', "one:two" => 'two'}, c.defaults)
  end
  
  def test_add_does_not_add_nested_delegates_if_the_option_if_type_is_hidden
    delegates = {
      :one => Nest.new(:one, ConfigurableClass, :one, :one=, :type => :hidden),
      :two => Config.new(:two, 'two', :two, :two=)
    }
    
    c.add(delegates)
    assert_equal({:two => 'two'}, c.defaults)
  end
  
  def test_add_raises_error_for_nesting_conflict
    delegates = {
      :one => Nest.new(:one, ConfigurableClass, :one, :one=, :type => :nest, :declaration_order => 1),
      'one:one' => Config.new(:two, 'two', :two, :two=, :declaration_order => 0)
    }
    
    e = assert_raises(ArgumentError) { c.add(delegates) }
    assert_equal "already set by a different option: \"one:one\"", e.message
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
    e = assert_raises(RuntimeError) { c.parse(["--opt"]) }
    assert_equal "no value provided for: --opt", e.message
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
  
  def test_parse_splits_string_argvs_using_Shellwords
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    args = c.parse("a --opt value b")
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_bang_splits_string_argvs_using_Shellwords
    value_in_block = nil
    c.on('--opt VALUE') {|value| value_in_block = value}
    
    args = c.parse!("a --opt value b")
    
    assert_equal("value", value_in_block)
    assert_equal(["a", "b"], args)
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
  
  def test_parse_clears_config_unless_specified_otherwise
    c.define('a', 'default')
    c.define('b', 'default')
    
    c.parse(["--a", "value"])
    assert_equal({"a" => "value", "b" => "default"}, c.config)
    
    c.parse(["--b", "value"])
    assert_equal({"a" => "default", "b" => "value"}, c.config)
  end
  
  def test_parse_does_not_add_defaults_unless_specified
    c.define('opt', 'default')
    args = c.parse(["a", "b"], :add_defaults => false)
    
    assert_equal({}, c.config)
    assert_equal(["a", "b"], args)
  end

  def test_parse_keeps_option_break_if_specified
    args = c.parse(["a", "--", "b"])
    assert_equal(["a", "b"], args)
    
    args = c.parse(["a", "--", "b"], :keep_break => true)
    assert_equal(["a", "--", "b"], args)
  end
  
  def test_parse_can_configure_option_break
    c.on('--opt') {}
    
    args = c.parse(["a", "---", "--opt", "b"], :option_break => "---")
    assert_equal(["a", "--opt", "b"], args)
    
    args = c.parse(["a", "---", "--opt", "b"], :option_break => /-{3}/)
    assert_equal(["a", "--opt", "b"], args)
  end
  
  def test_parse_sets_config_values
    c.define('opt', 'default')
    args = c.parse(["a", "--opt", "value", "b"])
    
    assert_equal({"opt" => "value"}, c.config)
    assert_equal(["a", "b"], args)
  end
  
  def test_parse_raises_error_for_unknown_option
    err = assert_raises(RuntimeError) { c.parse(["--unknown", "option"]) }
    assert_equal "unknown option: --unknown", err.message
    
    err = assert_raises(RuntimeError) { c.parse(["--unknown=option"]) }
    assert_equal "unknown option: --unknown", err.message
    
    err = assert_raises(RuntimeError) { c.parse(["--*"]) }
    assert_equal "unknown option: --*", err.message
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
    e = assert_raises(ArgumentError) { c.on('--[no-]opt VALUE') }
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
    e = assert_raises(RuntimeError) { c.parse(["a", "--opt", "one", "--opt", "three", "b"]) }
    assert_equal "too many assignments: \"opt\"", e.message
  end
  
  #
  # scan test
  #
  
  def test_scan_yields_each_non_opt_arg_to_block
    was_in_block = false
    c.on('--opt') { was_in_block = true }
    
    args = []
    c.scan(["a", "--opt", "b", "--opt", "c"]) {|arg| args << arg}
    
    assert_equal ["a", "b", "c"], args
    assert_equal true, was_in_block
  end
  
  def test_scan_returns_remaining_args
    was_in_block = false
    c.on('--opt') { was_in_block = true }
    
    args = []
    res = c.scan(["a", "--opt", "b", "--", "c"]) {|arg| args << arg}
    
    assert_equal ["a", "b"], args
    assert_equal ["c"], res
    assert_equal true, was_in_block
  end
  
  def test_scan_keeps_option_break_without_yielding_to_block
    args = []
    res = c.scan(["a", "--", "b"], :keep_break => true) {|arg| args << arg}
    
    assert_equal(["a"], args)
    assert_equal(["--", "b"], res)
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
        --list LIST
}
    assert_equal expected, "\n" + c.to_s
  end
  
  def test_to_s_for_options_without_long
    c.define('flag', true, :long => nil, :short => :f, :type => :flag, :desc => 'desc')
    c.define('opt', true, :long => nil, :short => :o, :arg_name => 'OPT', :desc => 'desc')
    c.define('alt', true, :desc => 'desc')
    expected = %Q{
    -f                               desc
    -o OPT                           desc
        --alt ALT                    desc
}
    assert_equal expected, "\n" + c.to_s
  end
  
  def test_to_s_format_for_nested_delegates
    delegates = {
      :opt => Config.new(:opt, 'value', :opt, :opt=, :desc => 'desc', :short => 'o', :type => :switch),
    }

    c.add(delegates, "nest")
    expected = %Q{
    -o, --nest:[no-]opt              desc
}
    assert_equal expected, "\n" + c.to_s
  end
end