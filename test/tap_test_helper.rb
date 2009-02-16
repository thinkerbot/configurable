require 'test/unit'

begin
  require 'lazydoc'
rescue(LoadError)
  puts %Q{
Tests probably cannot be run because the submodules have
not been initialized. Use these commands and try again:
 
% git submodule init
% git submodule update
 
}
  raise
end

class Test::Unit::TestCase
  undef_method :name
  alias name method_name
end unless Object.const_defined?(:MiniTest)