require 'test/unit'
require 'benchmark'
require 'configurable'

class ConfigHashBenchmark < Test::Unit::TestCase
  Config = Configurable::Config
  ConfigHash = Configurable::ConfigHash
  
  class Receiver
    include Configurable
    config :one
    config :two
    config :three
    config :four
    config :five
  end

  def test_initialize_speed
    puts "test_initialize_speed"
    
    Benchmark.bm(25) do |x|
      n = 10
      x.report("#{n}k reference") do 
        (n * 1000).times { Object.new }
      end
      
      x.report("#{n}k new") do 
        (n * 1000).times { Receiver.new }
      end
    end
  end
  
  def test_merge_speed
    puts "test_merge_speed"
    
    r = Receiver.new
    d = ConfigHash.new
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