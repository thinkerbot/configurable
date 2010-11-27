require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class CommandLineTestTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable
    config :a, nil   # -s, --long ARGNAME : summary...
    config :b, nil   # -S                 : flags are allowed
    config :c, nil   #     --LONG         : in any combo
    config :d, nil   #                    : while empty implies 'hidden'
    config :e, nil   # and none means 'default'
  end
  
  class EquivalentConfigClass
    include Configurable
    config :a, nil, :long => 'long', :short => 's', :arg_name => 'ARGNAME', :desc => 'summary...'
    config :b, nil, :long => nil, :short => 'S', :desc => 'flags are allowed'
    config :c, nil, :long => 'LONG', :short => nil, :desc => 'in any combo'
    config :d, nil, :hidden => true, :desc => "while empty implies 'hidden'"
    config :e, nil, :desc => "and none means 'default'"
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
        --LONG C                     in any combo
        --e E                        and none means 'default'
        --help                       print this help
    -s, --long ARGNAME               summary...
    -S B                             flags are allowed
}.lstrip

      assert_equal expected, stdout.join("\n")
    end
  end
end