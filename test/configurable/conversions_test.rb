require File.expand_path('../../test_helper', __FILE__)
require 'configurable/conversions'

class ConversionsTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  Conversions = Configurable::Conversions
  
  attr_accessor :configs
  
  def setup
    @configs = {}
    @configs.extend Conversions
  end
  
  def config(key, attrs={}, &caster)
    attrs[:caster] = caster
    Config.new(key, attrs)
  end
  
  class ConfiguableClass
    attr_reader :configs
    def initialize(configs)
      @configs = configs
      @configs.extend Conversions
    end
  end
  
  def nest_config(key, attrs={})
    attrs[:default] = ConfiguableClass.new(attrs.delete(:configs))
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
    configs[:a] = config(:a)
    configs[:b] = nest_config(:b, :configs => {
      :c => config(:c),
      :d => nest_config(:d, :configs => {
        :e => config(:e)
      })
    })
    
    parser = configs.to_parser
    parser.parse []
    assert_equal({
      :a => nil,
      :b => {
        :c => nil,
        :d => {
          :e => nil
        }
      }
    }, parser.config)
  
    parser.parse %w{--a 1 --b:c 2 --b:d:e 3}
    assert_equal({
      :a => '1',
      :b => {
        :c => '2',
        :d => {
          :e => '3'
        }
      }
    }, parser.config)
  end
  
  def test_to_parser_can_prevent_options_from_being_created_using_hidden
    configs[:a] = config(:one, :hidden => true)
    configs[:b] = nest_config(:b, :hidden => true, :configs => {
      :c => config(:c)
    })
    configs[:d] = nest_config(:d, :configs => {
      :e => config(:e, :hidden => true)
    })
    
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
    configs[:one] = config(:one) {|value| value.to_i }
    configs[:nest] = nest_config(:nest, :configs => {
      :two => config(:two) {|value| value.to_i }
    })
    
    source = {
      'one' => '1',
      'nest' => {'two' => '2'}
    }
    
    target = {
      :one => 1,
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
    configs[:one] = config(:one)
    configs[:nest] = nest_config(:nest, :configs => {
      :two => config(:two)
    })
    
    source = {
      :one => 1,
      :nest => {:two => 2}
    }
    
    target = {
      'one' => '1',
      'nest' => {'two' => '2'}
    }
    
    assert_equal(target, configs.export(source))
  end
end