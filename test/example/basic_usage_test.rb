require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class BasicUsageTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable

    config :flag, false             # a flag
    config :switch, true            # an on/off switch
    config :integer, 3              # integer only
    config :float, 3.14             # float only
    config :string, 'one'           # any string
  end
  
  def test_example
    instance = ConfigClass.new
    assert_equal 'one', instance.string
    instance.string = 'two'
    assert_equal 'two', instance.config[:string]
    instance.config[:string] = 'three'
    assert_equal 'three', instance.string

    expected = {
    :flag => false,
    :switch => true,
    :integer => 3,
    :float => 3.14,
    :string => 'three'
    }
    assert_equal expected, instance.config.to_hash

    argv = %w{a --flag --no-switch --integer 6 --float=6.022 b c}
    assert_equal ['a', 'b', 'c'], instance.config.parse(argv)
    
    expected = {
    :flag => true,
    :switch => false,
    :integer => 6,
    :float => 6.022,
    :string => 'three'
    }
    assert_equal expected, instance.config.to_hash

    stdout = []
    argv = %w{--help}
    instance.config.parse(argv) do |psr|
      psr.on('--help', 'print this help') do 
        stdout << "options:"
        stdout << psr
      end
    end

    expected = %q{
options:
        --flag                       a flag
        --float FLOAT                float only (3.14)
        --help                       print this help
        --integer INTEGER            integer only (3)
        --string STRING              any string (one)
        --[no-]switch                an on/off switch
}.lstrip

    assert_equal expected, stdout.join("\n")
  end
end