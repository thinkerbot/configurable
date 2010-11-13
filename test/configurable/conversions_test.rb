require File.expand_path('../../test_helper', __FILE__)
require 'configurable/conversions'
require 'configurable/config_types'

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
    attrs[:type] = StringType.subclass(&caster).new(attrs)
    Config.new(key, attrs)
  end
  
  class ConfiguableClass
    attr_reader :configs
    def initialize(configs)
      @configs = configs
      @configs.extend Conversions
    end
  end
  
  def nest(key, configs={}, attrs={})
    attrs[:default] = ConfiguableClass.new(configs)
    Nest.new(key, attrs)
  end
  
  #
  # to_parser test
  #
  
  def test_to_parser_returns_a_parser_initialized_with_configs
    configs[:one] = config(:one) {|value| value.to_i }
    
    parser = configs.to_parser
    args = parser.parse("a b --one 1 c")
    
    assert_equal ["a", "b", "c"], args
    assert_equal({:one => 1}, parser.config)
  end
  
  def test_to_parser_initializes_with_args_and_is_passed_to_block
    configs[:one] = config(:one)
    
    target = {}
    parser = configs.to_parser(target, :assign_defaults => false) {|psr| psr.on('--two') }
    
    assert_equal target, parser.config
    assert_equal false, parser.assign_defaults
    assert_equal ['--one', '--two'], parser.options.keys.sort
  end
  
  def test_to_parser_guesses_long_by_name
    configs[:one] = config(:one, :name => 'ONE')
    assert_equal ['--ONE'], configs.to_parser.options.keys
  end
  
  def test_to_parser_options_use_config_attrs_as_specifed
    configs[:one] = config(:one, :short => :S, :long => :LONG)
    
    parser = configs.to_parser
    assert_equal ['--LONG', '-S'], parser.options.keys.sort
    
    parser.parse('-S short')
    assert_equal({:one => 'short'}, parser.config)
    
    parser.parse('--LONG long')
    assert_equal({:one => 'long'}, parser.config)
  end
  
  def test_to_parser_handles_nested_configs
    configs[:one]  = config(:one)
    configs[:nest] = nest(:nest, :two => config(:two))
    
    parser = configs.to_parser
    parser.parse []
    assert_equal({
      :one  => nil,
      :nest => {:two => nil}
    }, parser.config)
  
    parser.parse %w{--one 1 --nest:two 2}
    assert_equal({
      :one  => '1',
      :nest => {:two => '2'}
    }, parser.config)
  end
  
  def test_to_parser_can_prevent_options_from_being_created_using_hidden
    configs[:a] = config(:a, :hidden => true)
    configs[:b] = nest(:b, {:c => config(:c)}, :hidden => true)
    configs[:d] = nest(:d, {:e => config(:e, :hidden => true)})
    
    parser = configs.to_parser
    assert_equal [], parser.options.keys.sort
    
    parser.parse
    assert_equal({}, parser.config)
  end
  
  #
  # to_default test
  #
  
  def test_to_default_returns_default_hash
    configs[:one] = config(:one, :default => 1)
    assert_equal({:one => 1}, configs.to_default)
  end
  
  #
  # import test
  #
  
  def test_import_maps_config_names_to_config_keys
    configs[:one] = config(:one)
    
    assert_equal({
      :one => 'NAME'
    }, configs.import(:one => 'KEY', 'one' => 'NAME'))
  end
  
  def test_import_casts_values
    configs[:one] = config(:one) {|value| value.to_i }
    
    assert_equal({
      :one => 1
    }, configs.import('one' => '1'))
  end
  
  def test_import_maps_ignores_unknown_names
    assert_equal({}, configs.import('unknown' => 'value'))
  end
  
  def test_import_recursively_maps_nested_configs
    configs[:one]  = config(:one) {|value| value.to_i }
    configs[:nest] = nest(:nest, :two => config(:two) {|value| value.to_i })
    
    source = {
      'one'  => '1',
      'nest' => {'two' => '2'}
    }
    
    target = {
      :one  => 1,
      :nest => {:two => 2}
    }
    
    assert_equal(target, configs.import(source))
  end
  
  #
  # export test
  #
  
  def test_export_maps_config_keys_to_config_names
    configs[:one] = config(:one)
    
    assert_equal({
      'one' => 'KEY'
    }, configs.export(:one => 'KEY', 'one' => 'NAME'))
  end
  
  def test_export_uncasts_values
    configs[:one] = config(:one)
    
    assert_equal({
      'one' => '1'
    }, configs.export(:one => 1))
  end
  
  def test_export_maps_ignores_unknown_keys
    assert_equal({}, configs.export(:unknown => 'value'))
  end
  
  def test_export_recursively_maps_nested_configs
    configs[:one]  = config(:one)
    configs[:nest] = nest(:nest, :two => config(:two))
    
    source = {
      :one  => 1,
      :nest => {:two => 2}
    }
    
    target = {
      'one'  => '1',
      'nest' => {'two' => '2'}
    }
    
    assert_equal(target, configs.export(source))
  end
  
  #
  # validate test
  #
  
  def test_validate_returns_a_hash_of_all_errors_for_the_input
    configs[:one] = config(:one, :options => ['a', 'b', 'c'])
    configs[:two] = config(:two, :options => [1, 2, 3])
    
    assert_equal({
    }, configs.validate(:one => 'a', :two => 3))
    
    assert_equal({
      :one => ['invalid value: "x"'],
      :two => ['invalid value: 6']
    }, configs.validate(:one => 'x', :two => 6))
  end
  
  def test_validate_checks_nested_configs
    configs[:one]  = config(:one, :options => ['a', 'b', 'c'])
    configs[:nest] = nest(:nest, :two => config(:two, :options => [1, 2, 3]))
    
    assert_equal({
    }, configs.validate(:one => 'a', :nest => {:two => 3}))
    
    assert_equal({
      :one  => ['invalid value: "x"'],
      :nest => {
        :two => ['invalid value: 6']
      }
    }, configs.validate(:one => 'x', :nest => {:two => 6}))
  end
end