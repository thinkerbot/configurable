require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class ReadmeTest < Test::Unit::TestCase
  
  class ConfigClass
    include Configurable

    config :key, 'default', :short => 'k'   # a simple config with short
    config :flag, false, &c.flag            # a flag config
    config :switch, false, &c.switch        # a --[no-]switch config
    config :num, 10, &c.integer             # integer only
    config :range, 1..10, &c.range          # range only
    config :upcase, 'default' do |value|    # custom transformation
      value.upcase
    end

    def initialize(overrides={})
      initialize_config(overrides)
    end
  end
  
  def test_quickstart
    parser = ConfigClass.parser
    assert_equal ConfigParser, parser.class

    expected = %Q{
    -k, --key KEY                    a simple config with short
        --flag                       a flag config
        --[no-]switch                a --[no-]switch config
        --num NUM                    integer only
        --range RANGE                range only
        --upcase UPCASE              custom transformation
}
    assert_equal expected, "\n" + parser.to_s

    assert_equal  ['one', 'two', 'three'], parser.parse("one two --key=value --flag --no-switch --num 8 --range a..z three")  
    expected = {
    :key => 'value',
    :flag => true,
    :switch => false,
    :num => '8',
    :range => 'a..z',
    :upcase => 'default'
    }
    assert_equal expected, parser.config  

    c = ConfigClass.new(parser.config) 
    expected = {
    :key => 'value',
    :flag => true,
    :switch => false,
    :num => 8,
    :range => 'a'..'z',
    :upcase => 'DEFAULT'
    }
    assert_equal expected, c.config.to_hash

    assert_equal 'DEFAULT', c.upcase

    c.config[:upcase] = 'neW valuE'
    assert_equal 'NEW VALUE', c.upcase

    c.upcase = 'fiNal Value'
    assert_equal 'FINAL VALUE', c.config[:upcase]

    assert_raise(Configurable::Validation::ValidationError) { c.num = 'blue' }

    yaml_str = %Q{
    key: a new value
    flag: false
    range: 1..100
    }

    c.reconfigure(YAML.load(yaml_str))
    expected = {
    :key => 'a new value',
    :flag => false,
    :switch => false,
    :num => 8,
    :range => 1..100,
    :upcase => 'FINAL VALUE'
    }
    assert_equal expected, c.config.to_hash
  end
  
  class ValidatingClass
    include Configurable

    config :int, 1, &c.integer                 # assures the input is an integer
    config :int_or_nil, 1, &c.integer_or_nil   # integer or nil only
    config :array, [], &c.array                # you get the idea
  end
  
  def test_validation
    vc = ValidatingClass.new

    vc.array = [:a, :b, :c]
    assert_equal [:a, :b, :c], vc.array

    vc.array = "[1, 2, 3]"
    assert_equal [1, 2, 3], vc.array
    
    assert_raise(Configurable::Validation::ValidationError) { vc.array = "string" }
  end
end