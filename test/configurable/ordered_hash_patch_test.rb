require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/class_methods'

# These are tests for the OrderedHashPatch, which is only
# going to be defined in ruby 1.8.*
class OrderedHashPatchTest < Test::Unit::TestCase
  OrderedHashPatch = Configurable::OrderedHashPatch
  
  #
  # keys test
  #
  
  def test_keys_are_returned_in_insertion_order
    h = OrderedHashPatch.new
    %w{a b c d e f g h}.each do |key|
      h[key] = key.to_sym
    end

    assert_equal %w{a b c d e f g h}, h.keys
  end
  
  #
  # each_pair test
  #
  
  def test_each_pair_iterates_keys_in_keys_order
    h = OrderedHashPatch.new
    %w{a b c d e f g h}.each do |key|
      h[key] = key.to_sym
    end
    
    order = []
    h.each_pair do |key, value|
      order << [key, value]
    end
    
    assert_equal [
      ['a', :a],
      ['b', :b],
      ['c', :c],
      ['d', :d],
      ['e', :e],
      ['f', :f],
      ['g', :g],
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
  
end if Configurable.const_defined?(:OrderedHashPatch)