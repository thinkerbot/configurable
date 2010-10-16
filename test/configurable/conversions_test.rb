require File.expand_path('../../test_helper', __FILE__)
require 'configurable/conversions'

class ConversionsTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  Conversions = Configurable::Conversions
  
  attr_accessor :configs
  
  def setup
    @configs = {:one => Config.new(:one)}
    @configs.extend Conversions
  end
  
  def cast_config(key, attrs={}, &caster)
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
    parser = configs.to_parser
    args = parser.parse("a b --one value c")
    
    assert_equal ["a", "b", "c"], args
    assert_equal({:one => 'value'}, parser.config)
  end
  
  def test_to_parser_initializes_with_args_and_is_passed_to_block
    target = {}
    parser = configs.to_parser(target, :assign_defaults => false) {|psr| psr.on('--two') }
    
    assert_equal target, parser.config
    assert_equal false, parser.assign_defaults
    assert_equal ['--one', '--two'], parser.options.keys.sort
  end
  
  def test_to_parser_guesses_long_by_name
    configs[:one] = Config.new(:one, :name => 'ONE')
    assert_equal ['--ONE'], configs.to_parser.options.keys
  end
  
  def test_to_parser_options_use_config_attrs_as_specifed
    configs[:one] = Config.new(:one, :short => :S, :long => :LONG)
    
    parser = configs.to_parser
    assert_equal ['--LONG', '-S'], parser.options.keys.sort
    
    parser.parse('-S short')
    assert_equal({:one => 'short'}, parser.config)
    
    parser.parse('--LONG long')
    assert_equal({:one => 'long'}, parser.config)
  end
  
  def test_to_parser_handles_nested_configs
    configs.clear
    configs[:a] = Config.new(:a)
    configs[:b] = nest_config(:b, :configs => {
      :c => Config.new(:c),
      :d => nest_config(:d, :configs => {
        :e => Config.new(:e)
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
    configs.clear
    configs[:a] = Config.new(:one, :hidden => true)
    configs[:b] = nest_config(:b, :hidden => true, :configs => {
      :c => Config.new(:c)
    })
    configs[:d] = nest_config(:d, :configs => {
      :e => Config.new(:e, :hidden => true)
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
    assert_equal({:one => nil}, configs.to_default)
  end
  
  #
  # keyify test
  #
  
  def test_keyify_maps_config_names_to_config_keys
    assert_equal({
      :one => 'NAME'
    }, configs.keyify(:one => 'KEY', 'one' => 'NAME'))
  end
  
  def test_keyify_maps_ignores_unknown_names
    assert_equal({}, configs.keyify('unknown' => 'value'))
  end
  
  def test_keyify_recursively_maps_nested_configs
    configs[:one] = Config.new(:one)
    configs[:nest] = nest_config(:nest, :configs => {
      :two => Config.new(:two)
    })
    
    source = {
      'one' => 'ONE',
      'nest' => {'two' => 'TWO'}
    }
    
    target = {
      :one => 'ONE',
      :nest => {:two => 'TWO'}
    }
    
    assert_equal(target, configs.keyify(source))
  end
  
  #
  # nameify test
  #
  
  def test_nameify_maps_config_keys_to_config_names
    assert_equal({
      'one' => 'KEY'
    }, configs.nameify(:one => 'KEY', 'one' => 'NAME'))
  end
  
  def test_nameify_maps_ignores_unknown_keys
    assert_equal({}, configs.nameify(:unknown => 'value'))
  end
  
  def test_nameify_recursively_maps_nested_configs
    configs[:one] = Config.new(:one)
    configs[:nest] = nest_config(:nest, :configs => {
      :two => Config.new(:two)
    })
    
    source = {
      :one => 'ONE',
      :nest => {:two => 'TWO'}
    }
    
    target = {
      'one' => 'ONE',
      'nest' => {'two' => 'TWO'}
    }
    
    assert_equal(target, configs.nameify(source))
  end
  
  #
  # cast test
  #
  
  def test_cast_casts_configs_keyed_by_key
    configs[:one] = cast_config(:one) {|value| value.to_i }
    
    source = {:one => '8'}
    result = configs.cast(source)
    
    assert_equal source.object_id, result.object_id
    assert_equal({:one => 8}, result)
  end
  
  def test_cast_ignores_configs_keyed_by_name
    configs[:one] = cast_config(:one) {|value| value.to_i }
    assert_equal({'one' => '8'}, configs.cast('one' => '8'))
  end
  
  def test_cast_allows_specification_of_an_alternate_target
    configs[:one] = cast_config(:one) {|value| value.to_i }
    
    source = {:one => '8'}
    target = {}
    result = configs.cast(source, target)
    assert_equal target.object_id, result.object_id
    
    assert_equal({:one => '8'}, source)
    assert_equal({:one => 8}, target)
  end
  
  def test_cast_recursively_casts_configs
    configs[:one] = cast_config(:one) {|value| value.to_i }
    configs[:nest] = nest_config(:nest, :configs => {
      :two => cast_config(:two) {|value| value.to_i }
    })

    assert_equal({
      :one => 8,
      :nest => {:two => 8}
    }, configs.cast(
      :one => '8',
      :nest => {:two => '8'}
    ))
  end
end