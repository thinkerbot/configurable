require 'test/unit'
require 'benchmark'
require 'config_parser'

class ConfigParserBenchmark < Test::Unit::TestCase

  def test_parser_speed
    puts "test_parser_speed"
    
    parser = ConfigParser.new do |psr|
      psr.on "-s", "--long LONG", "a standard option" do |value|
      end
      
      psr.on "--[no-]switch", "a switch" do |value|
      end
  
      psr.on "--flag", "a flag" do
      end
    end
    
    Benchmark.bm(25) do |x|
      argvs = Array.new(10000) do |n|
        %w{a b --long arg --switch --flag c}
      end
      
      x.report("10kx7 parse!") do
        argvs.each do |argv|
          parser.parse!(argv)
        end
      end
      
      argvs = Array.new(1000) do |n|
        %w{a b --long arg --switch --flag c} * 10
      end
      
      x.report("1kx70 parse!") do
        argvs.each do |argv|
          parser.parse!(argv)
        end
      end
    end
  end
end