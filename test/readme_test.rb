require File.expand_path('../test_helper', __FILE__)
require 'configurable'

class ReadmeTest < Test::Unit::TestCase

  class ConfigClass
    include Configurable
    config :flag, false                    # a flag
    config :switch, true                   # an on/off switch
    config :num, 3.14                      # a number
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
    'str' => 'value'
    }
    assert_equal expected, c.config.export
  
    c.config.import('flag' => 'true', 'num' => '2.71')
    expected = {
    :flag => true, 
    :switch => true,
    :num => 2.71, 
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
    assert_equal expected, (parser.parse "one two --flag --no-switch --num=-1 -s val three")
    
    expected = {
    :flag => true,
    :switch => false,
    :num => -1.0,
    :str => 'val'
    }
    assert_equal expected, parser.config
  
    expected = %Q{
        --flag                       a flag
    -h, --help                       print help
        --num NUM                    a number
    -s, --str STR                    a string, with a short
        --[no-]switch                an on/off switch
}
    assert_equal expected, "\n" + parser.to_s
  end
end