require File.expand_path('../../test_helper', __FILE__) 
require 'configurable/options'

class OptionsTest < Test::Unit::TestCase
  Config = Configurable::Config
  Options = Configurable::Options
  
  attr_reader :opts
  
  def setup
    @opts = Options.new
  end
  
  #
  # register test
  #
  
  def test_register_stores_options_by_type
    assert_equal({}, opts.registry)
    opts.register(:type, :class => Config)
    assert_equal({:class => Config}, opts.registry[:type])
  end
  
  def test_register_sets_class_to_Config_if_unspecified
    opts.register(:type)
    assert_equal({:class => Config}, opts.registry[:type])
  end
  
  def test_register_returns_options
    assert_equal({:class => Config}, opts.register(:type))
    assert_equal({:class => String}, opts.register(:type, :class => String))
  end
  
  class DefineTarget
  end
  
  def test_register_uses_block_to_define_a_Config_subclass_if_provided
    line = __LINE__ + 4
    options = opts.register(:type) do |name|
      %Q{
        def #{name}_success; :success; end
        def #{name}_failure; raise 'fail'; end
      }
    end
    
    clas = options[:class]
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
    options = opts.register(:type, :class => RegisterSuperclass) { }
    assert_equal RegisterSuperclass, options[:class].superclass
  end
  
  #
  # guess test
  #
  
  def test_options_guesses_type_based_on_matches_option
    a = opts.register(:one, :matches => String)
    b = opts.register(:two, :matches => Numeric)
    
    assert_equal a, opts.guess('')
    assert_equal b, opts.guess(8)
  end
  
  def test_guess_returns_empty_hash_for_no_matches
    assert_equal({}, opts.guess('abc'))
  end
  
  def test_guess_raises_error_for_multiple_matching_types
    opts.register(:one, :matches => String)
    opts.register(:two, :matches => Object)
    
    err = assert_raises(RuntimeError) { opts.guess 'abc' }
    assert_equal 'multiple guesses for config type: "abc" [:one, :two]', err.message
  end
  #
  # method_missing test
  #
  
  def test_missing_methods_return_options_if_a_registered_type
    opts.register(:example, :class => Config)
    assert_equal({:class => Config}, opts.example)
  end
end