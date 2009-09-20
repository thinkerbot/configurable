require 'test/unit'
require 'benchmark'
require 'configurable'

class ConfigurableBenchmark < Test::Unit::TestCase
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
      
      Receiver.cache_configurations(false)
      x.report("#{n}k new") do 
        (n * 1000).times { Receiver.new }
      end
      
      Receiver.cache_configurations(true)
      x.report("#{n}k new (cached)") do 
        (n * 1000).times { Receiver.new }
      end
    end
  end
  
  def test_merge_speed
    puts "test_merge_speed"
    
    config_hash = ConfigHash.new(Receiver.new)
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
      
      Receiver.cache_configurations(false)
      x.report("#{n}k") do 
        (n * 1000).times { config_hash.merge!(another) }
      end
      
      Receiver.cache_configurations(true)
      x.report("#{n}k (cached)") do 
        (n * 1000).times { config_hash.merge!(another) }
      end
      
      assert_equal 'one', config_hash.receiver.one
      assert_equal 'zero', config_hash[:zero]
    end
  end
end