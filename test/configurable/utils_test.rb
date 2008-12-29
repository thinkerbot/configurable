require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable'
require 'configurable/utils'
require 'fileutils'

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
  
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  IndifferentAccess = Configurable::IndifferentAccess
  
  DEFAULTS = {
    :sym => :value,
    'str' => 'value',
    :array => [1,2,3],
    :hash => {:key => 'value'}
  }
  
  TEST_ROOT = __FILE__.chomp('_test.rb')
  
  attr_reader :method_root
  
  def setup
    @method_root = File.join(TEST_ROOT, method_name)
  end
  
  def teardown
    unless ENV['keep_outputs']
      FileUtils.rm_r(TEST_ROOT) if File.exists?(TEST_ROOT)
    end
  end
  
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
      delegates[key] = Delegate.new(:r, :w, value)
    end
    
    assert_equal DEFAULTS, YAML.load(dump(delegates))
  end
  
  def test_dump_dumps_nested_delegate_to_target_as_hash
    one = {
      :one => Delegate.new(:r, :w, 'value')
    }
    two = {
      :key => Delegate.new(:r, :w, DelegateHash.new(one)), 
      :two => Delegate.new(:r, :w, 'value')
    }
    three = {
      :key => Delegate.new(:r, :w, DelegateHash.new(two)), 
      :three => Delegate.new(:r, :w, 'value')
    }
    
    assert_equal({
      :key => {
        :key => {
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
      delegates[key] = Delegate.new(:r, :w, value)
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
    delegates.extend(IndifferentAccess)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(:r, :w, value)
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
    delegates.extend(IndifferentAccess)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(:r, :w, value)
    end
    
    result = dump(delegates) do |key, value|
      "#{key} "
    end
    
    assert_equal %q{sym str array hash }, result
  end
  
  #
  # dump_file test
  #
  
  def test_dump_file_dumps_to_file
    FileUtils.mkdir_p(method_root)
    path = File.join(method_root, 'path.yml')
    
    delegates = OrderedHash.new(:sym, 'str', :array, :hash)
    delegates.extend(IndifferentAccess)
    DEFAULTS.each_pair do |key, value|
      delegates[key] = Delegate.new(:r, :w, value)
    end
    
    assert !File.exists?(path)
    dump_file(delegates, path)
    
    assert_equal %q{
sym: :value
str: value
array: 
- 1
- 2
- 3
hash: 
  :key: value
}, "\n" + File.read(path)
  end
  
  def test_dump_file_recursively_creates_dump_files_for_nested_delegates_based_on_key
    FileUtils.mkdir_p(method_root)
    three_path = File.join(method_root, 'path.yml')
    two_path = File.join(method_root, 'path/key.yml')
    one_path = File.join(method_root, 'path/key/key.yml')
    
    one = {
      :one => Delegate.new(:r, :w, 'value')
    }.extend(IndifferentAccess)
    two = {
      :key => Delegate.new(:r, :w, DelegateHash.new(one)), 
      :two => Delegate.new(:r, :w, 'value')
    }.extend(IndifferentAccess)
    three = {
      :key => Delegate.new(:r, :w, DelegateHash.new(two)), 
      :three => Delegate.new(:r, :w, 'value')
    }.extend(IndifferentAccess)
    
    assert !File.exists?(three_path)
    dump_file(three, three_path, true)

    assert_equal %q{
three: value
}, "\n" + File.read(three_path)

    assert_equal %q{
two: value
}, "\n" + File.read(two_path)

    assert_equal %q{
one: value
}, "\n" + File.read(one_path)
  end
end