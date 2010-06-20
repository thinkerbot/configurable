require File.expand_path('../test_helper', __FILE__)
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

class ConfigurableRemovalTest < Test::Unit::TestCase
  module X
    include Configurable
    config :key_x, :x
    config :key_y, :y
    config :key_z, :z
    remove_config :key_x
  end
  
  module Y
    include X
  end
  
  class Z
    include Y
  end
  
  class A
    include Configurable
    config :key_a, :a
    config :key_b, :b
    remove_config :key_a
  end
  
  class B < A
  end
  
  class C < B
    config :key_a, :A
    config :key_b, :B
  end
  
  def test_remove_config_removes_a_config_defined_in_self_and_subclasses
    assert_equal false, Z.respond_to?(:key_x)
    assert_equal :y,  Z.new.send(:key_y)
    assert_equal :z,  Z.new.send(:key_z)
    
    assert_equal false, A.respond_to?(:key_a)
    assert_equal :b,  A.new.send(:key_b)
    
    assert_equal false, B.respond_to?(:key_a)
    assert_equal :b,  B.new.send(:key_b)
  end
  
  def test_removed_configs_can_be_redefined
    assert_equal :A, C.new.key_a
    assert_equal :B, C.new.key_b
  end
  
  def test_remove_config_raises_error_for_config_not_defined_in_self
    err = assert_raises(NameError) { X.send(:remove_config, :key_x) }
    assert_equal ":key_x is not a config on ConfigurableRemovalTest::X", err.message
    
    err = assert_raises(NameError) { Y.send(:remove_config, :key_x) }
    assert_equal ":key_x is not a config on ConfigurableRemovalTest::Y", err.message
    
    err = assert_raises(NameError) { Z.send(:remove_config, :key_z) }
    assert_equal ":key_z is not a config on ConfigurableRemovalTest::Z", err.message
    
    err = assert_raises(NameError) { B.send(:remove_config, :key_b) }
    assert_equal ":key_b is not a config on ConfigurableRemovalTest::B", err.message
  end
end

class ConfigurableUndefTest < Test::Unit::TestCase
  module X
    include Configurable
    config :key_x, :x
    config :key_y, :y
    config :key_z, :z
    undef_config :key_x
  end
  
  module Y
    include X
    undef_config :key_y
  end
  
  class Z
    include Y
    undef_config :key_z
  end
  
  class A
    include Configurable
    config :key_a, :a
    config :key_b, :b
    undef_config :key_a
  end
  
  class B < A
    undef_config :key_b
  end
  
  class C < B
    config :key_a, :A
    config :key_b, :B
  end
  
  def test_undef_config_removes_a_defined_config_in_self_and_subclasses
    assert_equal false, Z.respond_to?(:key_x)
    assert_equal false, Z.respond_to?(:key_y)
    assert_equal false, Z.respond_to?(:key_z)
    
    assert_equal false, A.respond_to?(:key_a)
    assert_equal :b,  A.new.send(:key_b)
    
    assert_equal false, B.respond_to?(:key_a)
    assert_equal false,  B.respond_to?(:key_b)
  end
  
  def test_undefined_configs_can_be_redefined
    assert_equal :A, C.new.key_a
    assert_equal :B, C.new.key_b
  end
  
  def test_undef_config_raises_error_for_config_not_defined_anywhere_in_ancestry
    err = assert_raises(NameError) { X.send(:undef_config, :key_x) }
    assert_equal ":key_x is not a config on ConfigurableUndefTest::X", err.message
    
    err = assert_raises(NameError) { Y.send(:undef_config, :key_unknown) }
    assert_equal ":key_unknown is not a config on ConfigurableUndefTest::Y", err.message
    
    err = assert_raises(NameError) { Z.send(:undef_config, :key_unknown) }
    assert_equal ":key_unknown is not a config on ConfigurableUndefTest::Z", err.message
    
    err = assert_raises(NameError) { B.send(:undef_config, :key_unknown) }
    assert_equal ":key_unknown is not a config on ConfigurableUndefTest::B", err.message
  end
end
