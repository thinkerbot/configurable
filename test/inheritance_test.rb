require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class InheritanceTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate

  #
  # inheritance test
  #
  
  class IncludeBase
    include Configurable
    config :one, 'one'
  end
  
  class IncludeSubclass < IncludeBase
    config :two, 'two'
  end
  
  class OverrideSubclass < IncludeBase 
    config(:one, 'ONE') 
  end
  
  class ChangeDefaultSubclass < IncludeBase 
  end
  
  def test_subclasses_inherit_configurations
    assert_equal({:one => Delegate.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({
      :one => Delegate.new(:one, :one=, 'one'), 
      :two => Delegate.new(:two, :two=, 'two')
    }, IncludeSubclass.configurations)
  end
  
  def test_subclasses_inherit_accessors
    t = IncludeSubclass.new
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
  end
  
  def test_inherited_configurations_can_be_overridden
    assert_equal({:one => Delegate.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({:one => Delegate.new(:one, :one=, 'ONE')}, OverrideSubclass.configurations)
  end
  
  def test_manual_changes_to_inherited_configurations_do_not_propogate_to_superclass
    ChangeDefaultSubclass.configurations[:one].default = 'two'
    
    assert_equal({:one => Delegate.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({:one => Delegate.new(:one, :one=, 'two')}, ChangeDefaultSubclass.configurations)
  end
end
