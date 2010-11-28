require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class CommandLineTestTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable
    config :a, nil   # -a, --aaa ARGNAME  : cmdline options may be
    config :b, nil   # -b                 : declared in the docs
    config :c, nil   #     --ccc          : using a prefix
    config :d, nil   #                    : an empty prefix implies 'hidden'
    config :e, nil   # no prefix uses the defaults
  end
  
  class EquivalentConfigClass
    include Configurable
    config :a, nil, :long => 'aaa', :short => 'a', :arg_name => 'ARGNAME', :desc => 'cmdline options may be'
    config :b, nil, :long => nil, :short => 'b', :desc => 'declared in the docs'
    config :c, nil, :long => 'ccc', :short => nil, :desc => 'using a prefix'
    config :d, nil, :hidden => true, :desc => "an empty prefix implies 'hidden'"
    config :e, nil, :desc => "no prefix uses the defaults"
  end
  
  def test_example
    [ConfigClass, EquivalentConfigClass].each do |config_class|
      stdout = []
      argv = %w{--help}
      config_class.configs.to_parser do |psr|
        psr.on('--help', 'print this help') do 
          stdout << "options:"
          stdout << psr
        end
      end.parse(argv)

      expected = %q{
options:
    -a, --aaa ARGNAME                cmdline options may be
    -b B                             declared in the docs
        --ccc C                      using a prefix
    -e E                             no prefix uses the defaults
        --help                       print this help
}.lstrip

      assert_equal expected, stdout.join("\n"), stdout.join("\n")
    end
  end
end