require File.expand_path('../test_helper', __FILE__)
require 'configurable'

class ReadmeMinimalTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable
    config :key, 'default', :short => 'k'   # a sample config
  end

  def test_minimal_documentation
    c = ConfigClass.new
    assert_equal 'default', c.key
    c.key = 'new value'
    assert_equal 'new value', c.config[:key]

    parser = ConfigParser.new

    # add class configurations
    parser.add(ConfigClass.configurations)

    # define an option a-la OptionParser
    parser.on '-s', '--long ARGUMENT', 'description' do |value|
      parser[:long] = value
    end
    
    expected = ['one', 'two', 'three']
    assert_equal expected, parser.parse("one two --key value -s VALUE three")
                             
    expected = {
    :key => 'value',
    :long => 'VALUE'
    }
    assert_equal expected, parser.config

    expected = %Q{
    -k, --key KEY                    a sample config
    -s, --long ARGUMENT              description
}
    assert_equal expected, "\n" + parser.to_s
  end
end

class ReadmeTest < Test::Unit::TestCase
  
  class ConfigClass
    include Configurable

    # basic #

    config :key, 'default'                    # a simple config
    config :flag, false, &c.flag              # a flag config
    config :switch, false, &c.switch          # a --[no-]switch config
    config :num, 10, &c.integer               # integer only

    # fancy #

    config :select, 'a', &c.select('a','b')   # value must be 'a' or 'b'
    config :list, [], &c.list                 # allows a list of entries

    # custom #

    config :upcase, 'default' do |value|      # custom transformation
      value.upcase
    end

    config :alt, 'default',                   # alternative flags
      :short => 's',
      :long => 'long',
      :arg_name => 'CUSTOM'

    # Initializes a new instance, setting the overriding configs.
    def initialize(config={})
      initialize_config(config)
    end
  end
  
  def test_documentation
    parser = ConfigParser.new
    parser.add(ConfigClass.configurations)

    expected = ['a', 'b', 'c']
    assert_equal expected, parser.parse("a b --key=value --flag --no-switch --num 8 c")
    
    expected = {
    :key => 'value',
    :flag => true,
    :switch => false,
    :num => '8',
    :select => 'a',
    :list => [],
    :upcase => 'default',
    :alt => 'default'
    }
    assert_equal expected, parser.config

    expected = %Q{
        --key KEY                    a simple config
        --flag                       a flag config
        --[no-]switch                a --[no-]switch config
        --num NUM                    integer only
        --select SELECT              value must be 'a' or 'b'
        --list LIST                  allows a list of entries
        --upcase UPCASE              custom transformation
    -s, --long CUSTOM                alternative flags
}
    assert_equal expected, "\n" + parser.to_s

    c = ConfigClass.new(parser.config)
       
    expected = {
    :key => 'value',
    :flag => true,
    :switch => false,
    :num => 8,                    # no longer a string
    :select => 'a',
    :list => [],
    :upcase => 'DEFAULT',         # no longer downcase
    :alt => 'default'
    }
    assert_equal expected, c.config.to_hash

    assert_equal 'DEFAULT', c.upcase

    c.config[:upcase] = 'neW valuE'
    assert_equal 'NEW VALUE', c.upcase

    c.upcase = 'fiNal Value'
    assert_equal 'FINAL VALUE', c.config[:upcase]

    c.select = 'b'              # ok
    assert_raises(Configurable::Validation::ValidationError) { c.select = 'c' }
    assert_raises(Configurable::Validation::ValidationError) { c.config[:select] = 'c' }

    yaml_str = %Q{
    key: a new value
    flag: false
    }

    c.reconfigure(YAML.load(yaml_str))
    
    expected = {
    :key => 'a new value',
    :flag => false,
    :switch => false,
    :num => 8,
    :select => 'b',
    :list => [],
    :upcase => 'FINAL VALUE',
    :alt => 'default'
    }
    assert_equal expected, c.config.to_hash
  end
end