require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable'
require 'configurable/utils'


class Configurable::UtilsTest < Test::Unit::TestCase
  include Configurable::Utils
  
  # A hash that performs each_pair in a specified order
  class OrderedHash < Hash
    def initialize(*order)
      super()
      @order = order
    end
    
    def each_pair
      @order.each do |key|
        yield(key, self[key])
      end
    end
  end
  
  # A mock delgate class
  class Delegate
    attr_reader :default
    
    def initialize(default, is_nest=false)
      @default = default
      @is_nest = is_nest
    end
    
    def is_nest?
      @is_nest
    end
  end
  
  DEFAULTS = {
    :sym => :value,
    'str' => 'value',
    :array => [1,2,3],
    :hash => {:key => 'value'}
  }
  
  #
  # dump test
  #
  
  class DumpExample
    include Configurable

    config :sym, :value      # a symbol config
    config 'str', 'value'    # a string config
  end

  def test_dump_documentation
    expected = %q{
sym: :value
str: value
}
    assert_equal expected, dump(DumpExample.configurations, "\n")
  
    expected = %q{
# a symbol config
sym: :value

# a string config
str: value

}

    actual = dump(DumpExample.configurations, "\n") do |key, delegate|
      yaml = {key => delegate.default}.to_yaml[5..-1]
      "# #{delegate[:desc]}\n#{yaml}\n"
    end
    assert_equal expected, actual
  end
  
  def test_dump_dumps_delegate_defaults_to_target_as_yaml
    delegates = {}
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(value)
    end
    
    assert_equal DEFAULTS, YAML.load(dump(delegates))
  end
  
  def test_dump_dumps_nested_delegate_to_target_as_hash
    one = Configurable::DelegateHash.new({:key => Delegate.new('value')}, {:one => 'value'})
    two = Configurable::DelegateHash.new({:key => Delegate.new(one, true)}, {:two => 'value'})
    three = {
      :key => Delegate.new(two, true), 
      :three => Delegate.new('value')
    }
    
    assert_equal({
      :key => {
        :key => {
          :key => 'value',
          :one => 'value'
        },
        :two => 'value'
      },
      :three => 'value'
    }, YAML.load(dump(three)))
  end
  
  def test_dump_dumps_delegates_to_target_in_each_pair_order
    delegates = OrderedHash.new(:sym, 'str', :array, :hash)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(value)
    end
    
    assert_equal %q{
:sym: :value
str: value
:array: 
- 1
- 2
- 3
:hash: 
  :key: value
}, dump(delegates, "\n")
  end
  
  def test_dump_stringifies_symbol_keys_for_delegates_with_indifferent_access
    delegates = OrderedHash.new(:sym, 'str', :array, :hash)
    delegates.extend(Configurable::IndifferentAccess)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(value)
    end

    assert_equal %q{
sym: :value
str: value
array: 
- 1
- 2
- 3
hash: 
  :key: value
}, dump(delegates, "\n")
  end
  
  def test_dump_uses_block_to_format_each_line_in_the_dump
    delegates = OrderedHash.new(:sym, 'str', :array, :hash)
    delegates.extend(Configurable::IndifferentAccess)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(value)
    end
    
    result = dump(delegates) do |key, value|
      "#{key} "
    end
    
    assert_equal %q{sym str array hash }, result
  end
end