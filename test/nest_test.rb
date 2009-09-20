require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class NestTest < Test::Unit::TestCase
  ConfigHash = Configurable::ConfigHash
  ValidationError = Configurable::Validation::ValidationError
  
  #
  # nest test
  #
  
  class A
    include Configurable

    config :key, 'one'
    nest :nest do
      config :key, 'two'
    end
  end
  
  class B
    include Configurable

    config :key, 1, &c.integer
    nest :nest do 
      config :key, 2, &c.integer
      nest :nest do
        config :key, 3, &c.integer
      end
    end
  end

  class C
    include Configurable
    nest :a, A
    nest :b, B
  end
  
  def test_documentation
    a = A.new
    assert_equal 'one', a.key
    assert_equal 'one', a.config[:key]
  
    assert_equal 'two', a.nest.key
    assert_equal 'two', a.config[:nest][:key]
  
    a.nest.key = 'TWO'
    assert_equal 'TWO', a.config[:nest][:key]
  
    a.config[:nest][:key] = 2
    assert_equal 2, a.nest.key
  
    assert_equal({:key => 'one', :nest => {:key => 2}}, a.config.to_hash)
    assert_equal({:key => 2}, a.nest.config.to_hash)
    assert_equal A::Nest, a.nest.class
  
    c = C.new
    c.b.key = 7
    c.b.nest.key = "8"
    c.config[:b][:nest][:nest][:key] = "9"
  
    expected = {
    :a => {
      :key => 'one',
      :nest => {:key => 'two'}
    },
    :b => {
      :key => 7,
      :nest => {
        :key => 8,
        :nest => {:key => 9}
      }
    }}
    assert_equal expected, c.config.to_hash
  end
  
  #
  # nest class definition
  #
  
  class NestDefinesConstant
    include Configurable
    nest :nest
  end
  
  def test_nest_defines_a_nested_configurable_class
    assert NestDefinesConstant.const_defined?(:Nest)
    assert NestDefinesConstant::Nest.included_modules.include?(Configurable)
  end
  
  class NestDefinesConstantByAttribute
    include Configurable
    nest :nest, nil, :const_name => 'Alt'
  end
  
  def test_nest_allows_const_name_to_be_specified_as_an_attribute
    assert NestDefinesConstantByAttribute.const_defined?(:Alt)
  end
  
  class NestDoesNotDefineNilConstName
    include Configurable
    nest :nest, nil, :const_name => nil
  end
  
  def test_nest_does_not_set_const_name_if_nil
    assert !NestDefinesConstantByAttribute.const_defined?(:Nest)
    
    n = NestDoesNotDefineNilConstName.new
    assert n.nest.kind_of?(Configurable)
  end
  
  class InputConfigurableClass
    include Configurable
  end
  
  class NestInheritsFromConfigurableClass
    include Configurable
    nest :nest, InputConfigurableClass
  end
  
  def test_nest_uses_configurable_class_if_specified
    n = NestInheritsFromConfigurableClass.new
    assert n.nest.kind_of?(InputConfigurableClass)
  end
  
  def test_nest_sets_const_name_for_nested_class
    assert_equal InputConfigurableClass, NestInheritsFromConfigurableClass::Nest
  end
  
  class NestWithBlock
    include Configurable
    nest :nest do
      config :key, 'value'
      
      def say_hello
        "hello"
      end
    end
  end
  
  def test_nest_evaluates_block_in_the_nested_configurable_class_context
    n = NestWithBlock::Nest.new
    assert_equal({:key => 'value'}, n.config.to_hash)
    assert_equal "hello", n.say_hello
  end
  
  #
  # nest methods
  #
  
  class NestMethods
    include Configurable
    nest :nest
  end
  
  def test_nest_creates_accessor_for_nest_key
    methods = NestMethods.public_instance_methods.collect {|m| m.to_sym }
    assert methods.include?(:nest)
    assert methods.include?(:nest=)
  end
  
  class NestMethodsWithoutAccessors
    include Configurable
    nest :no_reader, nil, :reader => false
    nest :no_writer, nil, :writer => false
  end
  
  def test_nest_does_not_create_instance_accessors_unless_specified
    methods = NestMethodsWithoutAccessors.public_instance_methods.collect {|m| m.to_sym }
    assert !methods.include?(:no_reader)
    assert methods.include?(:no_reader=)
    
    assert methods.include?(:no_writer)
    assert !methods.include?(:no_writer=)
  end
  
  class NestInvalidInstanceAccessors
    include Configurable
  end
  
  def test_nest_raises_error_if_no_reader_and_writer_are_specified
    e = assert_raises(RuntimeError) do
      NestInvalidInstanceAccessors.send(:nest, :a, nil, :reader => nil)
    end
    assert_equal ":reader attribute cannot be nil", e.message
    
    e = assert_raises(RuntimeError) do
      NestInvalidInstanceAccessors.send(:nest, :b, nil, :writer => nil)
    end
    assert_equal ":writer attribute cannot be nil", e.message
  end
  
  #
  # nest config
  #
  
  class NestChild
    include Configurable
    config :key, 'value' do |input|
      input.downcase
    end
  end
  
  class NestParent
    include Configurable
    nest :nest, NestChild
    
    def initialize(config={})
      initialize_config(config)
    end
  end
  
  def test_nest_initializes_instance_of_nested_configurable_class
    p = NestParent.new
    assert_equal NestChild, p.nest.class
  end
  
  def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
    p = NestParent.new
    assert_equal({:key => 'value'}, p.nest.config.to_hash)
    
    p.config[:nest][:key] = 'zero'
    assert_equal({:key => 'zero'}, p.nest.config.to_hash)
    
    p.config[:nest] = {:key => 'two'}
    assert_equal({:key => 'two'}, p.nest.config.to_hash)
      
    p.nest.key = "two"
    assert_equal({:key => 'two'}, p.config[:nest])
    
    p.nest.reconfigure(:key => 'one')
    assert_equal({:key => 'one'}, p.config[:nest])
    
    p.nest.config[:key] = 'zero'
    assert_equal({:key => 'zero'}, p.config[:nest])
  end
  
  def test_modification_of_configs_uses_validation_block
    p = NestParent.new
    p.nest.key = "TWO"
    assert_equal({:key => 'two'}, p.config[:nest])
  end
  
  def test_instance_is_initialized_with_defaults
    p = NestParent.new 
    assert_equal({:nest => {:key => 'value'}}, p.config.to_hash)
    assert_equal({:key => 'value'}, p.nest.config.to_hash)
  end
  
  def test_instance_is_initialized_with_overrides
    p = NestParent.new :nest => {:key => 'one'}
    assert_equal({:nest => {:key => 'one'}}, p.config.to_hash)
    assert_equal({:key => 'one'}, p.nest.config.to_hash)
  end
  
  def test_instance_may_be_specified_as_config_value
    c = NestChild.new
    p = NestParent.new :nest => c
    assert_equal c.object_id, p.nest.object_id
  end
  
  def test_instance_may_be_set_during_reconfigure
    c = NestChild.new
    p = NestParent.new
    assert c.object_id != p.nest.object_id
    
    p.reconfigure :nest => c
    assert_equal c.object_id, p.nest.object_id
  end
  
  def test_instance_writer_is_validated
    p = NestParent.new
    assert_raises(ValidationError) { p.nest = Object.new }
  end
  
  #
  # recursive nest test
  #
  
  class RecursiveNest
    include Configurable
    
    def initialize(config={})
      initialize_config(config)
    end
    
    config :key, 'a' do |value|
      value.downcase
    end
    
    nest :nest do
      config :key, 'b' do |value|
        value.downcase
      end
      
      nest :nest do
        config :key, 'c' do |value|
          value.downcase
        end
      end
    end
  end
  
  def test_recursive_nesting_is_allowed
    r = RecursiveNest.new
    assert_equal({
      :key => 'a', 
      :nest => {
        :key => 'b', 
        :nest => {
          :key => 'c'
        }
      }
    }, r.config.to_hash)
  end
  
  def test_recursive_nests_initialize_correctly
    r = RecursiveNest.new(
      :key => 'ONE', 
      :nest => {
        :key => 'TWO', 
        :nest => {
          :key => 'THREE'
        }
      }
    )
    
    assert_equal({
      :key => 'one', 
      :nest => {
        :key => 'two', 
        :nest => {
          :key => 'three'
        }
      }
    }, r.config.to_hash)
  end
  
  #
  # infinite nest test
  #
  
  class InfiniteA
    include Configurable
  end
  
  class InfiniteB
    include Configurable
    nest :a, InfiniteA
  end
  
  class InfiniteC
    include Configurable
    nest :b, InfiniteB
  end
  
  def test_nest_raises_error_for_infinite_nest
    e = assert_raises(RuntimeError) { InfiniteA.send(:nest, :a, InfiniteA) }
    assert_equal "infinite nest detected", e.message
    
    e = assert_raises(RuntimeError) { InfiniteA.send(:nest, :c, InfiniteC) }
    assert_equal "infinite nest detected", e.message
  end

end