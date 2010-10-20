require File.expand_path('../test_helper', __FILE__)
require 'configurable'

class ReadmeTest < Test::Unit::TestCase

  class ConfigClass
    include Configurable
    config :flag, false                    # a flag
    config :switch, true                   # an on/off switch
    config :num, 3.14                      # a number
    config :lst, [1,2,3]                   # a list of integers
    config :str, 'value', :short => :s     # a string, with a short
  end
  
  def test_readme
    c = ConfigClass.new
    assert_equal 3.14, c.num

    c.num = 6.022
    assert_equal 6.022, c.config[:num]
    c.config[:num] = 1.61
    assert_equal 1.61, c.num

    expected = {
    'flag' => 'false',
    'switch' => 'true',
    'num' => '1.61',
    'lst' => ['1', '2', '3'], 
    'str' => 'value'
    }
    assert_equal expected, c.config.export
  
    c.config.import('flag' => 'true', 'num' => '2.71', 'lst' => ['8', '9'])
    expected = {
    :flag => true, 
    :switch => true,
    :num => 2.71, 
    :lst => [8,9],
    :str => 'value'
    }
    assert_equal expected, c.config.to_hash
    
    parser = ConfigClass.configs.to_parser do |psr|
      # define other options a-la OptionParser
      psr.on '-h', '--help', 'print help' do |value|
        puts "ConfigClass options:"
        puts parser
      end
    end
    
    assert_equal ConfigParser, parser.class
  
    expected = ['one', 'two', 'three']
    assert_equal expected, (parser.parse "one two --flag --no-switch --num=-1 --lst 3,6,9 -s val three")
    
    expected = {
    :flag => true,
    :switch => false,
    :num => -1.0,
    :lst => [3, 6, 9],
    :str => 'val'
    }
    assert_equal expected, parser.config
  
    expected = %Q{
        --flag                       a flag
    -h, --help                       print help
        --lst LST                    a list of integers (1,2,3)
        --num NUM                    a number (3.14)
    -s, --str STR                    a string, with a short (value)
        --[no-]switch                an on/off switch
}
    assert_equal expected, "\n" + parser.to_s
  end
end