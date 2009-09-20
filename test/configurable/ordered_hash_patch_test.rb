require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/class_methods'
  
# These are tests for the OrderedHashPatch, which is only used in ruby 1.8.* 
class OrderedHashPatchTest < Test::Unit::TestCase
  if RUBY_VERSION >= '1.9'

    def test_ordered_hash_patch_is_not_loaded_or_defined
      assert_equal nil, $".find {|path| path =~ /configurable\/ordered_hash_patch.rb/}
      assert !Configurable.const_defined?(:OrderedHashPatch)
    end
    
  else
    
  OrderedHashPatch = Configurable::OrderedHashPatch
  
  #
  # keys test
  #
  
  def test_keys_are_returned_in_insertion_order
    h = OrderedHashPatch.new
    %w{e f g a b c d h}.each do |key|
      h[key] = key.to_sym
    end

    assert_equal %w{e f g a b c d h}, h.keys
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_iterates_keys_in_keys_order
    h = OrderedHashPatch.new
    %w{e f g a b c d h}.each do |key|
      h[key] = key.to_sym
    end
    
    order = []
    h.each_pair do |key, value|
      order << [key, value]
    end
    
    assert_equal [
      ['e', :e],
      ['f', :f],
      ['g', :g],
      ['a', :a],
      ['b', :b],
      ['c', :c],
      ['d', :d],
      ['h', :h],
    ], order
  end
  
  #
  # dup test
  #
  
  def test_duplicates_have_independent_insertion_order
    h = OrderedHashPatch.new
    %w{a b c d}.each do |key|
      h[key] = key.to_sym
    end
    
    d = h.dup
    %w{e f g h}.each do |key|
      h[key] = key.to_sym
    end
    
    %w{h g f e}.each do |key|
      d[key] = key.to_sym
    end
    
    assert_equal %w{a b c d e f g h}, h.keys
    assert_equal %w{a b c d h g f e}, d.keys
  end
  
  #
  # YAML tests
  #
  
  def test_ordered_hash_preserves_order_over_dump_load
    h = OrderedHashPatch.new
    %w{e f g a b c d h}.each do |key|
      h[key] = key.to_sym
    end
    
    d = YAML.load(YAML.dump(h))
    assert d == h
    assert d.object_id != h.object_id
    
    order = []
    d.each_pair do |key, value|
      order << key
    end
    assert_equal %w{e f g a b c d h}, order
  end
  
  def test_ordered_hash_can_be_unfaithfully_loaded_from_hash_yaml
    yaml = %Q{--- !map:Configurable::OrderedHashPatch 
e: :e
f: :f
g: :g
a: :a
b: :b
c: :c
d: :d
h: :h
}
    d = YAML.load(yaml)
    assert_equal OrderedHashPatch, d.class

    order = []
    d.each_pair do |key, value|
      order << key
    end
    assert %w{e f g a b c d h} != order
    assert_equal %w{a b c d e f g h}, order.sort
  end
  
  end
end