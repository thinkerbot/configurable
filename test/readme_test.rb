require File.expand_path('../test_helper', __FILE__)
require 'configurable'

class ReadmeTest < Test::Unit::TestCase

  class ConfigClass
    include Configurable
    config :flag, false    # a flag
    config :switch, true   # an on/off switch
    config :num, 3.14      # a number
    config :lst, [1,2,3]   # a list of integers
    config :str, 'one'     # a string
  end
  
  def test_readme
    c = ConfigClass.new
    assert_equal 'one', c.str
    c.str = 'two'
    assert_equal 'two', c.config[:str]
    c.config[:str] = 'three'
    assert_equal 'three', c.str

    expect = {
    :flag => false, 
    :switch => true,
    :num => 3.14,
    :lst => [1, 2, 3], 
    :str => 'three'
    }
    assert_equal expect, c.config.to_hash
  
    c.config.import(
      'flag'   => true,
      'num'    => 6.022
    )
    
    expect = {
    'flag'   => true, 
    'switch' => true,
    'num'    => 6.022,
    'lst'    => [1, 2, 3], 
    'str'    => 'three'
    }
    assert_equal expect, c.config.export
    
    params = {
      'flag'   => 'true',      # checkbox
      'switch' => 'true',      # radio button
      'num'    => '2.71',      # text input
      'lst'    => ['2', '6']   # list input (lst[]=2&lst[]=6)
    }

    expect = {
    :flag    => true, 
    :switch  => true,
    :num     => 2.71, 
    :lst     => [2, 6],
    :str     => 'three'
    }
    assert_equal expect, c.config.import(params).to_hash
    
    argv = %w{a --flag --no-switch --num 6.022 --lst 7 --lst 8,9 b c}

    expect = ['a', 'b', 'c']
    assert_equal expect, c.config.parse(argv)
    
    expect = {
    :flag   => true, 
    :switch => false,
    :num    => 6.022,
    :lst    => [7, 8, 9], 
    :str    => 'three'
    }
    assert_equal expect, c.config.to_hash

    stdout = []
    parser = c.config.parser do |psr|
      psr.on '-h', '--help', 'print help' do
        stdout << "options:"
        stdout << psr
      end
    end

    parser.parse('--help')
    
    expect = %q{
options:
        --flag                       a flag
    -h, --help                       print help
        --lst LST...                 a list of integers (1,2,3)
        --num NUM                    a number (3.14)
        --str STR                    a string (one)
        --[no-]switch                an on/off switch
}
    assert_equal expect, "\n" + stdout.join("\n")
  end
end