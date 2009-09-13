require 'test/unit'
require 'benchmark'

# Benchmarks for constructing configuration inheritance using arrays.
module DslForArrays
  module ClassMethods
    attr_accessor :values
  
    def self.initialize(base)
      base.values = []
    end
  
    def inherited(base)
     ClassMethods.initialize(base)
     super
    end
    
    def add(key, value)
      values << [key, value]
    end
    
    def get(key)
      each_ancestor do |ancestor|
        ancestor.values.each do |(k,v)|
          return v if k == key
        end
      end
    end
    
    def merge
      hash = {}
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.values.each {|(k,v)| hash[k] = v }
      end
      
      hash
    end
    
    def keys
      keys = []
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.values.each {|(k,v)| keys << k }
      end
      
      keys.uniq!
      keys
    end
    
    def each
      ancestors.reverse.each do |ancestor|
        next unless ancestor.kind_of?(ClassMethods)
        ancestor.values.each do |entry|
          yield(entry)
        end
      end
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

class ArrayInheritanceCheck < Test::Unit::TestCase
  class A
    include DslForArrays
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
        n.times { A.values.dup }
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
  
  def test_each
    results = []
    A.each {|entry| results << entry }
    assert_equal [[:a, 'a'], [:b, 'b']], results
    
    results = []
    B.each {|entry| results << entry }
    assert_equal [[:a, 'a'], [:b, 'b']], results

    results = []
    C.each {|entry| results << entry }
    assert_equal [[:a, 'a'], [:b, 'b'], [:b, 'B'], [:c, 'C']], results
    
    Benchmark.bm(25) do |x|
      n = 100000
      
      x.report("each A") do
        n.times { A.each {} }
      end
      
      x.report("each B") do
        n.times { B.each {} }
      end
      
      x.report("each C") do
        n.times { C.each {} }
      end
    end
  end
end
