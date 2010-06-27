require File.expand_path('../../test_helper', __FILE__) 
require 'configurable/options'

class OptionsTest < Test::Unit::TestCase
  Config = Configurable::Config
  Options = Configurable::Options
  
  attr_reader :ops
  
  def setup
    @ops = Options.new
  end
  
  #
  # register test
  #
  
  def test_register_stores_options_by_type
    assert_equal({}, ops.registry)
    ops.register(:type, :class => Config)
    assert_equal({:class => Config}, ops.registry[:type])
  end
  
  def test_register_sets_class_to_Config_if_unspecified
    ops.register(:type)
    assert_equal({:class => Config}, ops.registry[:type])
  end
  
  def test_register_returns_class_option
    assert_equal Config, ops.register(:type)
    assert_equal String, ops.register(:type, :class => String)
  end
  
  class DefineTarget
  end
  
  def test_register_uses_block_to_define_a_Config_subclass_if_provided
    line = __LINE__ + 4
    clas = ops.register(:type) do |name|
      %Q{
        def #{name}_success; :success; end
        def #{name}_failure; raise 'fail'; end
      }
    end
    
    assert_equal Config, clas.superclass
    clas.new(:key).define_on(DefineTarget)
    
    target = DefineTarget.new
    assert_equal :success, target.key_success
    
    err = assert_raises(RuntimeError) { target.key_failure }
    assert_equal 'fail', err.message
    assert_equal "#{__FILE__}:#{line}:in `key_failure'", err.backtrace[0]
  end
  
  class RegisterSuperclass < Config
  end
  
  def test_register_subclasses_class_if_provided
    clas = ops.register(:type, :class => RegisterSuperclass) { }
    assert_equal RegisterSuperclass, clas.superclass
  end
  
  #
  # method_missing test
  #
  
  def test_missing_methods_return_options_if_a_registered_type
    ops.register(:example, :class => Config)
    assert_equal({:class => Config}, ops.example)
  end
  
end