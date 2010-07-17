require File.expand_path('../../test_helper', __FILE__)
require 'config_parser/option'

class OptionTest < Test::Unit::TestCase
  Option = ConfigParser::Option
  
  #
  # initialize tests
  #
  
  def test_initialization
    o = Option.new(:long => 'key')
    assert_equal '--key', o.long
    assert_equal nil, o.short
    assert_equal nil, o.arg_name
    assert_equal nil, o.desc
    assert_equal nil, o.block
  end
  
  def test_initialization_with_options
    b = lambda {}
    o = Option.new(:long => 'long', :short => 's', :desc => 'some desc', :arg_name => 'name', &b)
    assert_equal '--long', o.long
    assert_equal '-s', o.short
    assert_equal 'name', o.arg_name
    assert_equal 'some desc', o.desc
    assert_equal b, o.block
  end
  
  def test_initialization_formats_switches_as_necessary
    o = Option.new(:long => 'long', :short => 's')
    assert_equal '--long', o.long
    assert_equal '-s', o.short
    
    o = Option.new(:long => '--long', :short => '-s')
    assert_equal '--long', o.long
    assert_equal '-s', o.short
  end
  
  def test_initialization_raises_error_for_bad_switches
    e = assert_raises(ArgumentError) { Option.new(:long => '') }
    assert_equal "invalid long option: --", e.message
    
    e = assert_raises(ArgumentError) { Option.new(:long => '1') }
    assert_equal "invalid long option: --1", e.message
    
    e = assert_raises(ArgumentError) { Option.new(:long => '---long') }
    assert_equal "invalid long option: ---long", e.message
    
    e = assert_raises(ArgumentError) { Option.new(:short => '--long') }
    assert_equal "invalid short option: --long", e.message
    
    e = assert_raises(ArgumentError) { Option.new(:short => '1') }
    assert_equal "invalid short option: -1", e.message
    
    e = assert_raises(ArgumentError) { Option.new(:short => '') }
    assert_equal "invalid short option: -", e.message
  end
  
  def test_options_may_be_initialized_with_no_long_option
    opt = Option.new
    assert_equal nil, opt.long
  end
  
  #
  # switches test
  #
  
  def test_switches_returns_the_non_nil_long_and_short_options
    opt = Option.new(:long => 'long')
    assert_equal ["--long"], opt.switches
    
    opt = Option.new(:long => 'long', :short => 's')
    assert_equal ["--long", '-s'], opt.switches
    
    opt = Option.new
    assert_equal [], opt.switches
  end
  
  #
  # parse test (without arg_name)
  #
  
  def test_parse_with_no_arg_name_calls_block
    was_in_block = false
    opt = Option.new do |*args| 
      assert args.empty?
      was_in_block = true
    end

    opt.parse('--switch', nil, [])
    assert was_in_block
  end
  
  def test_parse_without_arg_name_returns_nil_if_no_block_is_given
    opt = Option.new
    assert_equal nil, opt.parse('--switch', nil, [])
  end
  
  def test_parse_without_arg_name_returns_block_value
    opt = Option.new { 'return value' }
    assert_equal 'return value', opt.parse('--switch', nil, [])
  end
  
  def test_parse_with_no_arg_name_raises_error_if_value_is_provided
    opt = Option.new
    
    e = assert_raises(RuntimeError) { opt.parse('--switch', 'value', []) }
    assert_equal "value specified for flag: --switch", e.message
  end
  
  #
  # parse test (with arg_name)
  #
  
  def test_parse_with_arg_name_calls_block_with_value
    value_in_block = false
    opt = Option.new(:arg_name => 'ARG') {|input| value_in_block = input }

    opt.parse('--switch', 'value', [])
    assert_equal 'value', value_in_block
  end
  
  def test_parse_with_arg_name_pulls_value_from_argv_if_no_value_is_given
    value_in_block = false
    opt = Option.new(:arg_name => 'ARG') {|input| value_in_block = input }

    argv = ['value']
    opt.parse('--switch', nil, argv)
    assert_equal 'value', value_in_block
    assert_equal [], argv
  end
  
  def test_parse_with_arg_name_returns_value_if_no_block_is_given
    opt = Option.new(:arg_name => 'ARG')
    assert_equal 'value', opt.parse('--switch', 'value', [])
  end
  
  def test_parse_with_arg_name_returns_block_value
    opt = Option.new(:arg_name => 'ARG') {|value| 'return value' }
    assert_equal 'return value', opt.parse('--switch', 'value', [])
  end
  
  def test_parse_with_arg_name_raises_error_if_no_value_is_provided_and_argv_is_empty
    opt = Option.new(:arg_name => 'ARG')
    
    e = assert_raises(RuntimeError) { opt.parse('--switch', nil, []) }
    assert_equal "no value provided for: --switch", e.message
  end
  
  #
  # to_s test
  #
  
  def test_to_s_formats_option_for_the_command_line
    opt = Option.new(:long => 'long', :arg_name => 'KEY')
    assert_equal "        --long KEY                                                              ", opt.to_s
    
    opt = Option.new(:long => 'long', :short => 's', :arg_name => 'KEY', :desc => "description of key")
    assert_equal "    -s, --long KEY                   description of key                         ", opt.to_s
  end
  
  def test_to_s_wraps_long_descriptions
    opt = Option.new(:long => 'long', :desc => "a really long description of key " * 4)
    
    expected = %q{
        --long                       a really long description of key a really  
                                     long description of key a really long      
                                     description of key a really long           
                                     description of key                         }
                                     
    assert_equal expected, "\n" + opt.to_s
  end
  
  def test_to_s_indents_long_headers
    opt = Option.new(
      :short => 's',
      :long => '--a:nested:and-really-freaky-long-option', 
      :desc => "a really long description of key " * 2)
      
    expected = %q{
    -s, --a:nested:and-really-freaky-long-option                                
                                     a really long description of key a really  
                                     long description of key                    }
                                     
    assert_equal expected, "\n" + opt.to_s
  end
end