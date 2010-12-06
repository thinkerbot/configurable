require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class CommandLineTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable
    config :flag, false    # a flag
    config :switch, true   # an on/off switch
    config :num, 3.14      # a number
    config :lst, [1,2,3]   # a list of integers
    config :nest do
      config :str, 'one'   # a string
    end
  end

  def test_command_line_options
    parser  = ConfigClass.configs.to_parser
    parser.parse("a --flag --no-switch --num 6.02 b c") do |args, config|
      assert_equal ['a', 'b', 'c'], args
      
      expected = {
      :flag   => true, 
      :switch => false,
      :num    => 6.02,
      :lst    => [1, 2, 3], 
      :nest   => {:str => 'one'}
      }
      assert_equal expected, config
    end

    c = ConfigClass.new
    expected = ['a', 'b', 'c']
    assert_equal expected, c.config.parse('a --lst 7 --lst 8,9 --nest:str=two b c')
    
    expected = {
    :flag   => false, 
    :switch => true,
    :num    => 3.14,
    :lst    => [7, 8, 9], 
    :nest   => {:str => 'two'}
    }
    assert_equal expected, c.config.to_hash

    stdout = []
    c.config.parse('--help') do |psr|
      psr.on('--help', 'print this help') do 
        stdout << "options:"
        stdout << psr
      end
    end
    
    expected = %q{
options:
        --flag                       a flag
        --help                       print this help
        --lst LST...                 a list of integers (1,2,3)
        --nest:str STR               a string (one)
        --num NUM                    a number (3.14)
        --[no-]switch                an on/off switch
}
    assert_equal expected, "\n" + stdout.join("\n")
  end
  
  class AltClass
    include Configurable
    config :a, nil   # -a, --aaa ARGNAME  : cmdline options may be
    config :b, nil   # -b                 : declared in the docs
    config :c, nil   #     --ccc          : using a prefix
    config :d, nil   #                    : an empty prefix implies 'hidden'
    config :e, nil   # no prefix uses the defaults
    config :f, nil   # -f [OPTIONAL]      : bracket argname means 'optional'
    
    config :g, []    # -g, --ggg LIST     : same rules for list opts
    config :nest do
      config :i, nil # -i, --iii NEST     : and same for nested opts
    end
  end

  def test_alt_command_line_options
    stdout = []
    AltClass.configs.to_parser do |psr|
      psr.on('-h', '--help', 'print this help') do 
        stdout << "options:"
        stdout << psr
      end
    end.parse('--help')

    expected = %q{
options:
    -a, --aaa ARGNAME                cmdline options may be
    -b B                             declared in the docs
        --ccc C                      using a prefix
    -e E                             no prefix uses the defaults
    -f [OPTIONAL]                    bracket argname means 'optional'
    -g, --ggg LIST...                same rules for list opts
    -h, --help                       print this help
    -i, --iii NEST                   and same for nested opts
}
    assert_equal expected, "\n" + stdout.join("\n")
  end
  
  class ManualClass
    include Configurable
    config :key, nil, {
      :long     => 'long',
      :short    => 's',
      :arg_name => 'ARGNAME',
      :desc     => 'summary',
      :hint     => 'hint',
      :optional => false,
      :hidden   => false
    }
  end

  def test_manual_command_line_options
    stdout = []
    ManualClass.configs.to_parser do |psr|
      psr.on('-h', '--help', 'print this help') do 
        stdout << "options:"
        stdout << psr
      end
    end.parse('--help')

    expected = %q{
options:
    -h, --help                       print this help
    -s, --long ARGNAME               summary (hint)
}
    assert_equal expected, "\n" + stdout.join("\n")
  end
end