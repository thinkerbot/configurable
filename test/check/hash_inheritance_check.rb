require 'test/unit'
require 'benchmark'

# Benchmarks for constructing configuration inheritance using ordered hashes.
if RUBY_VERSION < '1.9'
  class OrderedHash < Hash
    def initialize
      super
      @insertion_order = []
    end
    
    # ASET insertion, tracking insertion order.
    def []=(key, value)
      @insertion_order << key unless @insertion_order.include?(key)
      super
    end
    
    # Keys, sorted into insertion order
    def keys
      super.sort_by do |key|
        @insertion_order.index(key) || length
      end
    end
    
    def merge!(another)
      another.each_pair do |key, value|
        self[key] = value
      end
    end
    
    # Yields each key-value pair to the block in insertion order.
    def each_pair
      keys.each do |key|
        yield(key, fetch(key))
      end
    end
    
    # Ensures the insertion order of duplicates is separate from parents.
    def initialize_copy(orig)
      super
      @insertion_order = orig.instance_variable_get(:@insertion_order).dup
    end
  end
else
  OrderedHash = Hash
end

module DslForHash
  module ClassMethods
    attr_accessor :hash
  
    def self.initialize(base)
      base.hash = OrderedHash.new
    end
  
    def inherited(base)
     ClassMethods.initialize(base)
     super
    end
    
    def add(key, value)
      hash[key] = value
    end
    
    def get(key)
      each_ancestor do |ancestor|
        # best case assume nil/false values are unallowed
        if value = ancestor.hash[key]
          return value
        end
      end
    end
    
    def merge
      hash = OrderedHash.new
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        hash.merge!(ancestor.hash)
      end
      
      hash
    end
    
    def keys
      keys = []
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.hash.keys.each {|k| keys << k }
      end
      
      keys.uniq!
      keys
    end
    
    def each_pair
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.hash.each_pair do |key, value|
          yield(key, value)
        end
      end
    end
    
    def map(source={})
      delegates = merge
      
      source_values = {}
      source.each_key do |key|
        if delegate = delegates[key]
          # if source_values.has_key?(delegate)
          #   key = delegates.keys.find {|k| delegates[k] == delegate }
          #   raise "multiple values mapped to #{key.inspect}"
          # end
          
          source_values[delegate] = source.delete(key)
        end
      end
      
      results = {}
      delegates.each_pair do |key, delegate|
        value = case
        when source_values.has_key?(delegate)
          source_values[delegate]
        else
          delegate
        end
        
        results[key] = [value, results.length]
      end
      results
    end
    
    def each_ancestor
      yield(self)
    
      blank, *ancestors = self.ancestors
      ancestors.each do |ancestor|
        yield(ancestor) if ancestor.kind_of?(ClassMethods)
      end
    
      nil
    end
  end
  
  module ModuleMethods
    module_function
    
    def included(base)
      base.extend ClassMethods
      base.extend ModuleMethods unless base.kind_of?(Class)

      # initialize any class variables
      ClassMethods.initialize(base)
    end
  end
  
  extend ModuleMethods
end

class HashInheritanceCheck < Test::Unit::TestCase
  class A
    include DslForHash
    add :a, 'a'
    add :b, 'b'
  end
  
  class B < A
  end
  
  class C < B
    add :b, 'B'
    add :c, 'C'
  end
  
  @@header = false
  def setup
    unless @@header
      puts "\n#{self.class}"
      @@header = true
    end
  end
  
  def test_get
    assert_equal 'a', A.get(:a)
    assert_equal 'b', A.get(:b)
    assert_equal nil, A.get(:c)
    
    assert_equal 'a', B.get(:a)
    assert_equal 'b', B.get(:b)
    assert_equal nil, B.get(:c)
    
    assert_equal 'a', C.get(:a)
    assert_equal 'B', C.get(:b)
    assert_equal 'C', C.get(:c)
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("get (best)") do
        n.times { C.get(:b) }
      end
      
      x.report("get (worst)") do
        n.times { C.get(:a) }
      end
    end
  end
  
  def test_merge
    assert_equal({:a => 'a', :b => 'b'}, A.merge)
    assert_equal({:a => 'a', :b => 'b'}, B.merge)
    assert_equal({:a => 'a', :b => 'B', :c => 'C'}, C.merge)
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("dup") do
        n.times { A.hash.dup }
      end
      
      x.report("merge A") do
        n.times { A.merge }
      end
      
      x.report("merge B") do
        n.times { B.merge }
      end
      
      x.report("merge C") do
        n.times { C.merge }
      end
    end
  end
  
  def test_keys
    assert_equal([:a, :b], A.keys)
    assert_equal([:a, :b], B.keys)
    assert_equal([:a, :b, :c], C.keys)
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("keys A") do
        n.times { A.keys }
      end
      
      x.report("keys B") do
        n.times { B.keys }
      end
      
      x.report("keys C") do
        n.times { C.keys }
      end
    end
  end
  
  def test_each_pair
    results = []
    A.each_pair {|k, v| results << [k, v] }
    assert_equal [[:a, 'a'], [:b, 'b']], results
    
    results = []
    B.each_pair {|k, v| results << [k, v] }
    assert_equal [[:a, 'a'], [:b, 'b']], results

    results = []
    C.each_pair {|k, v| results << [k, v] }
    assert_equal [[:a, 'a'], [:b, 'b'], [:b, 'B'], [:c, 'C']], results
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("each_pair A") do
        n.times { A.each_pair {} }
      end
      
      x.report("each_pair B") do
        n.times { B.each_pair {} }
      end
      
      x.report("each_pair C") do
        n.times { C.each_pair {} }
      end
    end
  end
  
  def test_map
    assert_equal({:a => ['a', 0], :b => ['b', 1]}, A.map)
    assert_equal({:a => ['a', 0], :b => ['b', 1]}, B.map)
    assert_equal({:a => ['a', 0], :b => ['B', 1], :c => ['C', 2]}, C.map)
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("map A") do
        n.times { A.map }
      end
      
      x.report("map B") do
        n.times { B.map }
      end
      
      x.report("map C") do
        n.times { C.map }
      end
    end
  end
  
  def test_map_with_values
    assert_equal({:a => ['a', 0], :b => ['Q', 1]}, A.map(:b => 'Q'))
    assert_equal({:a => ['a', 0], :b => ['Q', 1]}, B.map(:b => 'Q'))
    assert_equal({:a => ['a', 0], :b => ['Q', 1], :c => ['C', 2]}, C.map(:b => 'Q'))
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("map(values) A") do
        n.times { A.map(:b => 'Q') }
      end
      
      x.report("map(values) B") do
        n.times { B.map(:b => 'Q') }
      end
      
      x.report("map(values) C") do
        n.times { C.map(:b => 'Q') }
      end
    end
  end
end