require File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/nest_delegate'

class NestDelegateTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  
  attr_reader :c
  
  def setup
    @c = NestDelegate.new('key')
  end
  
end