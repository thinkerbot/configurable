require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

# These tests follow those for the DSL pattern: http://gist.github.com/181961
# Their odd construction (ex A.new.send(:key_x)) is to more closely match the
# original tests.
class ConfigurableInheritanceTest < Test::Unit::TestCase
  
  module X
    include Configurable
    config :key_x, :x
  end

  module Y
    include X
    config :key_y, :y
  end

  class A
    include Y
    config :key_a, :a
  end

  class B < A
    config :key_b, :b
  end

  def test_configs_from_included_module_are_inherited_in_class_and_subclass
    assert_equal :x, A.new.send(:key_x)
    assert_equal :y, A.new.send(:key_y)
    assert_equal :a, A.new.send(:key_a)

    assert_equal :x, B.new.send(:key_x)
    assert_equal :y, B.new.send(:key_y)
    assert_equal :a, B.new.send(:key_a)
    assert_equal :b, B.new.send(:key_b)
  end
end

class ModifiedConfigurableInheritanceTest < Test::Unit::TestCase
  module X
    include Configurable
    config :key_x, :x
  end

  module Y
    include X
    config :key_y, :y
  end

  class A
    include Y
    config :key_a, :a
  end

  class B < A
    config :key_b, :b
  end

  ######################################################
  # late include into module X, and define a new method
  module LateInModule
    include Configurable
    config :key_late_in_module, :late_in_module
  end

  module X
    include LateInModule
    config :key_late_x, :late_x
  end

  ######################################################
  # late include into class A, and define a new method
  module LateInClass
    include Configurable
    config :key_late_in_class, :late_in_class
  end

  class A
    include LateInClass
    config :key_late_a, :late_a
  end

  ######################################################
  # define a class after late include
  class DefinedAfterLateInclude
    include X
  end

  ######################################################
  # inherit a class after late include
  class InheritAfterLateInclude < A
  end

  def test_late_inclusion_works_for_classes_but_not_modules
    assert_equal :x, A.new.send(:key_x)
    assert_equal :y, A.new.send(:key_y)
    assert_equal :a, A.new.send(:key_a)
    assert_equal :late_x, A.new.send(:key_late_x)
    assert_equal :late_a, A.new.send(:key_late_a)
    assert_equal false, A.new.respond_to?(:key_method_late_in_module)
    assert_equal :late_in_class, A.new.send(:key_late_in_class)

    assert_equal :x, B.new.send(:key_x)
    assert_equal :y, B.new.send(:key_y)
    assert_equal :a, B.new.send(:key_a)
    assert_equal :b, B.new.send(:key_b)
    assert_equal :late_x, B.new.send(:key_late_x)
    assert_equal :late_a, B.new.send(:key_late_a)
    assert_equal false, B.new.respond_to?(:key_method_late_in_module)
    assert_equal :late_in_class, B.new.send(:key_late_in_class)

    assert_equal :x, DefinedAfterLateInclude.new.send(:key_x)
    assert_equal :late_x, DefinedAfterLateInclude.new.send(:key_late_x)
    assert_equal :late_in_module, DefinedAfterLateInclude.new.send(:key_late_in_module)

    assert_equal :x, InheritAfterLateInclude.new.send(:key_x)
    assert_equal :y, InheritAfterLateInclude.new.send(:key_y)
    assert_equal :a, InheritAfterLateInclude.new.send(:key_a)
    assert_equal :late_x, InheritAfterLateInclude.new.send(:key_late_x)
    assert_equal :late_a, InheritAfterLateInclude.new.send(:key_late_a)
    assert_equal false, InheritAfterLateInclude.new.respond_to?(:key_method_late_in_module)
    assert_equal :late_in_class, InheritAfterLateInclude.new.send(:key_late_in_class)
  end
end