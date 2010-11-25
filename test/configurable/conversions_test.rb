require File.expand_path('../../test_helper', __FILE__)
require 'configurable/conversions'
require 'configurable/config_classes'

class ConversionsTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
  Conversions = Configurable::Conversions
  
  attr_accessor :configs
  
  def setup
    @configs = {}
    @configs.extend Conversions
  end
  
  def config(key, attrs={}, &caster)
    type_class = caster ? StringType.subclass(&caster) : StringType
    attrs[:type] = type_class.new(attrs)
    configs[key] = SingleConfig.new(key, attrs)
  end
  
  #
  # to_parser test
  #
  
  def test_to_parser_returns_a_parser_initialized_with_configs
    config(:one) {|value| value.to_i }
    
    parser = configs.to_parser
    args = parser.parse("a b --one 1 c")
    
    assert_equal ["a", "b", "c"], args
    assert_equal({:one => 1}, parser.config)
  end
  
  def test_to_parser_initializes_with_args_and_is_passed_to_block
    config(:one)
    
    target = {}
    parser = configs.to_parser(target, :assign_defaults => false) {|psr| psr.on('--two') }
    
    assert_equal target, parser.config
    assert_equal false, parser.assign_defaults
    assert_equal ['--one', '--two'], parser.options.keys.sort
  end
  
  def test_to_parser_guesses_long_by_name
    config(:one, :name => 'ONE')
    
    assert_equal ['--ONE'], configs.to_parser.options.keys
  end
  
  def test_to_parser_options_use_config_attrs_as_specifed_in_desc
    config(:one, :desc => {:short => :S, :long => :LONG})
    
    parser = configs.to_parser
    assert_equal ['--LONG', '-S'], parser.options.keys.sort
    
    parser.parse('-S short')
    assert_equal({:one => 'short'}, parser.config)
    
    parser.parse('--LONG long')
    assert_equal({:one => 'long'}, parser.config)
  end
  
  #
  # to_default test
  #
  
  def test_to_default_returns_default_hash
    config(:one, :default => 1)
    config(:two, :default => 2)
    
    assert_equal({
      :one => 1, 
      :two => 2
    }, configs.to_default)
  end
  
  #
  # import test
  #

  def test_import_maps_config_names_to_config_keys
    config(:one)

    assert_equal({
      :one => 'NAME'
    }, configs.import(
      :one  => 'KEY', 
      'one' => 'NAME'
    ))
  end

  def test_import_imports_values
    config(:one) {|value| value.to_i }

    assert_equal({
      :one => 1
    }, configs.import(
      'one' => '1'
    ))
  end

  def test_import_ignores_unknown_names
    assert_equal({}, configs.import('unknown' => 'value'))
  end

  #
  # export test
  #

  def test_export_maps_config_keys_to_config_names
    config(:one)

    assert_equal({
      'one' => 'KEY'
    }, configs.export(
      :one  => 'KEY', 
      'one' => 'NAME'
    ))
  end

  def test_export_exports_values
    config(:one)

    assert_equal({
      'one' => '1'
    }, configs.export(
      :one => 1
    ))
  end

  def test_export_ignores_unknown_keys
    assert_equal({}, configs.export(:unknown => 'value'))
  end
end