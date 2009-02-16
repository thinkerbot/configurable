require 'rubygems'
require 'test/unit'

class Test::Unit::TestCase
  undef_method :name
  alias name method_name
end unless Object.const_defined?(:MiniTest)