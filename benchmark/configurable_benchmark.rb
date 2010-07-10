require File.expand_path('../benchmark_helper', __FILE__)
require 'configurable'

class ConfigurableBenchmark < Test::Unit::TestCase
  ConfigHash = Configurable::ConfigHash
  
  class Reference
    attr_accessor :one, :two, :three
    
    def initialize
      @one = nil
      @two = nil
      @three = nil
    end
  end
  
  class Receiver
    include Configurable
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end
  
  def test_initialize_speed
    puts "test_initialize_speed"
    
    Benchmark.bm(25) do |x|
      n = 10
      
      x.report("#{n}k Reference") do 
        (n * 1000).times { Reference.new }
      end
      
      x.report("#{n}k Configurable (cold)") do 
        (n * 1000).times { Receiver.new }
      end
      
      x.report("#{n}k Configurable (warm)") do 
        (n * 1000).times { Receiver.new }
      end
    end
  end
  
  def test_merge_speed
    puts "test_merge_speed"
    
    config_hash = Receiver.new.config
    hash = {}
    
    Benchmark.bm(25) do |x|
      another = {}
      %w{zero one two three four five six seven eight nine}.each do |key|
        another[key.to_sym] = key
      end
      
      n = 10
      x.report("#{n}k Hash") do 
        (n * 1000).times { hash.merge!(another) }
      end
      
      x.report("#{n}k ConfigHash (cold)") do 
        (n * 1000).times { config_hash.merge!(another) }
      end
      
      x.report("#{n}k ConfigHash (warm)") do 
        (n * 1000).times { config_hash.merge!(another) }
      end
      
      assert_equal 'one', config_hash.receiver.one
      assert_equal 'zero', config_hash[:zero]
    end
  end
end