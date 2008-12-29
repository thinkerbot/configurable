require 'test/unit'
require 'benchmark'
require 'configurable/delegate_hash'

class DelegateHashBenchmark < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  
  class Receiver
    attr_accessor :one, :two, :three, :four, :five
  end

  def test_merge_speed
    puts "test_merge_speed"
    
    r = Receiver.new
    d = DelegateHash.new(
      :one => Delegate.new(:one),
      :two => Delegate.new(:two),
      :three => Delegate.new(:three),
      :four => Delegate.new(:four),
      :five => Delegate.new(:five))
    hash = {}
    
    Benchmark.bm(25) do |x|
      another = {}
      %w{zero one two three four five six seven eight nine}.each do |key|
        another[key.to_sym] = key
      end
      
      n = 10
      x.report("#{n}k reference") do 
        (n * 1000).times { hash.merge!(another) }
      end
      
      x.report("#{n}k unbound") do 
        (n * 1000).times { d.merge!(another) }
      end
      
      d.bind(r)
      x.report("#{n}k bound") do 
        (n * 1000).times { d.merge!(another) }
      end
      
      assert_equal 'one', r.one
      assert_equal 'zero', d[:zero]
    end
  end
end