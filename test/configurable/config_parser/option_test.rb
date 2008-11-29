require  File.join(File.dirname(__FILE__), '../../tap_test_helper')
require 'configurable/config_parser/option'

class OptionTest < Test::Unit::TestCase
  Option =  Configurable::ConfigParser::Option
  
  #
  # initialize tests
  #
  
  def test_initialization
    o = Option.new('key', 'value')
    assert_equal 'key', o.key
    assert_equal 'value', o.default
    assert_equal '--key', o.long
    assert_equal nil, o.short
    assert_equal nil, o.desc
    assert_equal nil, o.block
  end
  
  def test_initialization_with_options
    b = lambda {}
    o = Option.new('key', 'value', :long => 'long', :short => 's', :desc => 'some desc', &b)
    assert_equal 'key', o.key
    assert_equal 'value', o.default
    assert_equal '--long', o.long
    assert_equal '-s', o.short
    assert_equal 'some desc', o.desc
    assert_equal b, o.block
  end
  
  def test_options_may_be_initialized_with_no_long_option
    opt = Option.new('key', 'value', :long => nil)
    assert_equal nil, opt.long
  end
  
  #
  # switches test
  #
  
  def test_switches_returns_the_non_nil_long_and_short_options
    opt = Option.new('key', 'value')
    assert_equal ["--key"], opt.switches
    
    opt = Option.new('key', 'value', :long => 'long', :short => 's')
    assert_equal ["--long", '-s'], opt.switches
    
    opt = Option.new('key', 'value', :long => nil)
    assert_equal [], opt.switches
  end
  
  #
  # parse test
  #
  
  def test_parse_sets_the_value_in_config_by_key
    opt = Option.new('key', 'default')
    config = {}
    
    opt.parse('--key', 'value', [], config)
    assert_equal({'key' => 'value'}, config)
  end
  
  def test_parse_shifts_the_next_argv_as_value_if_value_is_nil
    opt = Option.new('key', 'default')
    config = {}
    argv = ['value']
    
    opt.parse('--key', nil, argv, config)
    assert_equal({'key' => 'value'}, config)
    assert_equal([], argv)
  end
  
  def test_parse_overrides_the_existing_key_without_error
    opt = Option.new('key', 'default')
    config = {'key' => 'another'}
    
    opt.parse('--key', 'value', [], config)
    assert_equal({'key' => 'value'}, config)
  end
  
  def test_parse_raises_error_if_no_value_is_available
    opt = Option.new('key', 'default')
    e = assert_raise(RuntimeError) { opt.parse('--key', nil, [], {})  }
    assert_equal "no value provided for: --key", e.message
  end
  
  #
  # process test
  #
  
  def test_process_passes_keyed_value_to_block_and_sets_result_in_config
    opt = Option.new('key', 'default') {|value| value.upcase}
    config = {'key' => 'value'}
    
    opt.process(config)
    assert_equal({'key' => 'VALUE'}, config)
  end
  
  def test_process_uses_default_if_config_has_no_value_set_to_key
    opt = Option.new('key', 'default') {|value| value.upcase}
    config = {}
    
    opt.process(config)
    assert_equal({'key' => 'DEFAULT'}, config)
  end
  
  #
  # to_s test
  #
  
  def test_to_s_formats_option_for_the_command_line
    opt = Option.new('key', 'default')
    assert_equal "        --key KEY                                                               ", opt.to_s
    
    opt = Option.new('key', 'default', :long => 'long', :short => 's', :desc => "description of key")
    assert_equal "    -s, --long KEY                      description of key                      ", opt.to_s
  end
end