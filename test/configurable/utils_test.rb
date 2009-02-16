require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable'
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
    @method_root = File.join(TEST_ROOT, name)
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
      yaml = YAML.dump({key => delegate.default})[5..-1]
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
  
  def test_dump_file_recursively_creates_dump_files_for_nested_delegates_when_recurse_is_true
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
    assert !File.exists?(two_path)
    assert !File.exists?(one_path)
    
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
  
  def test_dump_file_dumps_to_a_single_file_when_recurse_is_false
    FileUtils.mkdir_p(method_root)
    path = File.join(method_root, 'path.yml')
    
    one = OrderedHash.new()
    one[:one] = Delegate.new(:r, :w, 'value')

    two = OrderedHash.new(:key, :two)
    two[:key] = Delegate.new(:r, :w, DelegateHash.new(one))
    two[:two] = Delegate.new(:r, :w, 'value')

    three = OrderedHash.new(:key, :three)
    three[:key] = Delegate.new(:r, :w, DelegateHash.new(two))
    three[:three] = Delegate.new(:r, :w, 'value')

    assert !File.exists?(path)
    dump_file(three, path)

    assert_equal({
    :key => {
      :key => {
        :one => 'value'}, 
      :two => 'value'}, 
    :three => 'value'}, YAML.load(File.read(path)))
  end
  
  def test_dump_file_uses_block_to_format_each_line_in_the_dump
    FileUtils.mkdir_p(method_root)
    path = File.join(method_root, 'path.yml')

    one = OrderedHash.new()
    one[:one] = Delegate.new(:r, :w, 'value')

    two = OrderedHash.new(:key, :two)
    two[:key] = Delegate.new(:r, :w, DelegateHash.new(one))
    two[:two] = Delegate.new(:r, :w, 'value')

    three = OrderedHash.new(:key, :three)
    three[:key] = Delegate.new(:r, :w, DelegateHash.new(two))
    three[:three] = Delegate.new(:r, :w, 'value')

    assert !File.exists?(path)
    dump_file(three, path) {|key, delegate| "#{key} "}
    
    # note only the keys in three are shown, since
    # recurse is false.
    assert_equal %q{key three }, File.read(path)
  end
  
  def test_dump_file_uses_block_to_format_each_line_in_a_recursive_dump
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
    assert !File.exists?(two_path)
    assert !File.exists?(one_path)
    
    dump_file(three, three_path, true) {|key, delegate| "#{key} "}

    assert_equal %q{three }, File.read(three_path)
    assert_equal %q{two }, File.read(two_path)
    assert_equal %q{one }, File.read(one_path)
  end
  
  #
  # load_file test
  #
  
  def prepare_yaml(path, obj)
    path = File.join(method_root, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'w') do |file| 
      file << YAML.dump(obj) if obj
    end
    path
  end
  
  def test_load_file_raises_for_non_existant_file
    path = File.join(method_root, "non_existant.yml")
    assert !File.exists?(path)
    assert_equal({}, load_file(path))
  end
  
  def test_load_file_returns_empty_hash_for_empty_file
    path = prepare_yaml("non_existant.yml", nil)
    
    assert File.exists?(path)
    assert_equal "", File.read(path)
    assert_equal({}, load_file(path))
  end
  
  def test_load_file_loads_existing_files_as_yaml
    path = prepare_yaml("file.yml", {'key' => 'value'})
    assert_equal({'key' => 'value'}, load_file(path))
    
    path = prepare_yaml("file.yml", [1,2])
    assert_equal([1,2], load_file(path))
  end
  
  def test_load_file_recursively_loads_files
    path = prepare_yaml("a.yml", {'key' => 'a value'})
           prepare_yaml("a/b.yml", 'b value')
           prepare_yaml("a/c.yml", 'c value')
    
    a = {'key' => 'a value', 'b' => 'b value', 'c' => 'c value'}
    assert_equal(a, load_file(path, true))
  end
  
  def test_load_file_recursively_loads_directories
    path = prepare_yaml("a.yml", {'key' => 'value'})
           prepare_yaml("a/b/c.yml", 'c value')
           prepare_yaml("a/c/d.yml", 'd value')
           
    a = {
       'key' => 'value',
       'b' => {'c' => 'c value'},
       'c' => {'d' => 'd value'}
    }
    assert_equal(a, load_file(path, true))
  end
  
  def test_recursive_loading_with_files_and_directories
    path = prepare_yaml("a.yml", {'key' => 'a value'})
           prepare_yaml("a/b.yml", {'key' => 'b value'})
           prepare_yaml("a/b/c.yml", 'c value')
           
           prepare_yaml("a/d.yml", {'key' => 'd value'})
           prepare_yaml("a/d/e/f.yml", 'f value')
    
    d = {'key' => 'd value', 'e' => {'f' => 'f value'}}
    b = {'key' => 'b value', 'c' => 'c value'}
    a = {'key' => 'a value', 'b' => b, 'd' => d}
    
    assert_equal(a, load_file(path, true))
  end
  
  def test_recursive_loading_does_not_override_values_set_in_parent
    path = prepare_yaml("a.yml", {'a' => 'set value', 'b' => 'set value'})
           prepare_yaml("a/b.yml", 'recursive value')
           prepare_yaml("a/c.yml", 'recursive value')
           
    a = {
      'a' => 'set value',
      'b' => 'set value',
      'c' => 'recursive value'
    }
    
    assert_equal(a, load_file(path, true))
  end
  
  def test_load_file_does_not_recusively_load_file_unless_specified
    path = prepare_yaml("a.yml", {'key' => 'a value'})
           prepare_yaml("a/b.yml", {'key' => 'ab value'})
           
    a = {'key' => 'a value'}
            
    assert_equal(a, load_file(path))
  end
  
  def test_recursive_loading_raises_error_when_two_files_map_to_the_same_value
    path = prepare_yaml("a.yml", {})
    one = prepare_yaml("a/b.yml", 'one')
    two = prepare_yaml("a/b.yaml", 'two')
           
    e = assert_raise(RuntimeError) { load_file(path, true) }
    assert_equal "multiple files load the same key: [\"b.yaml\", \"b.yml\"]", e.message
  end
  
  def test_dump_file_does_not_create_files_when_preview_is_true
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
    assert !File.exists?(two_path)
    assert !File.exists?(one_path)
    
    preview = dump_file(three, three_path, true, true)
    
    assert_equal([
      [three_path, "three: value\n"],
      [two_path, "two: value\n"],
      [one_path, "one: value\n"]
    ], preview)
    
    assert !File.exists?(three_path)
    assert !File.exists?(two_path)
    assert !File.exists?(one_path)
  end
    
end