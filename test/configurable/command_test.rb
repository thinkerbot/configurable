require File.expand_path('../../test_helper', __FILE__)
require 'configurable/command'

class CommandTest < Test::Unit::TestCase
  Command = Configurable::Command
  
  class NameCommand < Command
  end
  
  def test_name_corresponds_to_underscore_basename
    assert_equal 'name_command', NameCommand.name
  end
  
  # CommandTest::DescCommand::desc subject
  # comment
  class DescCommand < Command
  end
  
  def test_desc_resolves_command_documentation
    desc = DescCommand.desc
    
    assert_equal 'subject', desc.to_s
    assert_equal 'subject', desc.subject
    assert_equal 'comment', desc.comment
  end
  
  class ArgsCommand < Command
    def process(a, b='B', *c)
    end
  end
  
  def test_args_resolves_process_args
    assert_equal "A B='B' C...", ArgsCommand.args.to_s
  end
  
  #
  # call test
  #
  
  class CallCommand < Command
    attr_accessor :args
    
    def process(*args)
      @args = args
      :result
    end
  end
  
  def test_call_splats_args_to_process_and_returns_result
    cmd = CallCommand.new
    assert_equal :result, cmd.call(['a', 'b', 'c'])
    assert_equal ['a', 'b', 'c'], cmd.args
  end
  
  #
  # config test
  #
  
  class ConfigCommand < Command
    config :n, 1
    
    def process(str)
      str * n
    end
  end
  
  def test_configs_are_available_for_use_in_process
    cmd = ConfigCommand.new(:n => 3)
    assert_equal '...', cmd.process('.')
  end
end