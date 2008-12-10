# Checks the behavior of option parser

require 'test/unit'
require 'optparse'

class OptparseCheck < Test::Unit::TestCase
  #include Benchmark

  def test_option_parser_parses_options_in_argument_order
    values = []
    
    opts = OptionParser.new
    opts.on("-a", "--option-a INPUT") {|value| values << value}
    opts.on("-b", "--option-b INPUT") {|value| values << value}
    
    opts.parse ["-a", "one", "-b", "two"]
    opts.parse ["-b", "one", "-a", "two"]
    
    assert_equal ["one", "two", "one", "two"], values
    assert_equal %Q{Usage: rake_test_loader [options]
    -a, --option-a INPUT
    -b, --option-b INPUT
}, opts.to_s
  end
  
  def test_option_parser_parses_tail_options_in_argument_order
    values = []
    
    opts = OptionParser.new
    opts.on_tail("-a", "--option-a INPUT") {|value| values << value}
    opts.on("-b", "--option-b INPUT") {|value| values << value}
    
    opts.parse ["-a", "one", "-b", "two"]
    opts.parse ["-b", "one", "-a", "two"]
    
    assert_equal ["one", "two", "one", "two"], values
    assert_equal %Q{Usage: rake_test_loader [options]
    -b, --option-b INPUT
    -a, --option-a INPUT
}, opts.to_s
  end
  
  def test_option_parser_parses_head_options_in_argument_order
    values = []
    
    opts = OptionParser.new
    opts.on("-a", "--option-a INPUT") {|value| values << value}
    opts.on_head("-b", "--option-b INPUT") {|value| values << value}
    
    opts.parse ["-a", "one", "-b", "two"]
    opts.parse ["-b", "one", "-a", "two"]
    
    assert_equal ["one", "two", "one", "two"], values
    
    assert_equal %Q{Usage: rake_test_loader [options]
    -b, --option-b INPUT
    -a, --option-a INPUT
}, opts.to_s
  end
  
  def test_option_parser_does_not_raise_error_for_double_assignment
    values = []

    opts = OptionParser.new
    opts.on("-a", "--option-a INPUT") {|value| values << value}

    assert_nothing_raised { opts.parse ["-a", "one", "-a", "two"] }
    assert_equal ["one", "two"], values
  end
end