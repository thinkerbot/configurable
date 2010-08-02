require File.expand_path('../test_helper', __FILE__)
require 'configurable'
require 'tempfile'

class ConfigurableTest < Test::Unit::TestCase
  Config = Configurable::Config
  ConfigHash = Configurable::ConfigHash
  
  #
  # documentation test
  #
  
  class ConfigClass
    include Configurable
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  end
  
  class ValidationClass
    include Configurable
    config_type(:upcase) {|v| v.upcase }
    config(:one, 'one', :type => :upcase)
    config :two, 2
  end

  module A
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end

  class B
    include A
  end

  class C < B
    config :b, 'B'
    config :c, 'C'
  end
  
  class NestingClass
    include Configurable
    config :one, 'one'
    nest :two do
      config :three, 'three'
    end
  end
  
  class AlternativeClass
    include Configurable

    config :sym, 'value', :reader => :get_sym, :writer => :set_sym

    def get_sym
      @sym
    end

    def set_sym(input)
      @sym = input.to_sym
    end
  end

  class AttributesClass
    include Configurable
    config_type(:upcase) {|v| v.upcase }

    config :a, 'A', :type => :upcase
    config :b, 'B', :type => :upcase
  end
  
  def test_documentation
    c = ConfigClass.new
    assert_equal Configurable::ConfigHash, c.config.class
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, c.config.to_hash)
  
    c.config[:one] = 'ONE'
    assert_equal 'ONE', c.one
    assert_equal({:one => 'ONE', :two => 'two', :three => 'three'}, c.config.to_hash)
  
    c.config[:undeclared] = 'value'
    assert_equal({:undeclared => 'value'}, c.config.store)
  
    ###
    c = ValidationClass.new
    assert_equal({:one => 'ONE', :two => 2}, c.config.to_hash)
  
    c.one = 'aNothER'             
    assert_equal 'ANOTHER', c.one
  
    c.two = -2
    assert_equal(-2, c.two)
    c.two = "3"
    assert_equal 3, c.two
    assert_raises(ArgumentError) { c.two = 'str' }

    ###
    assert_equal({:a => 'a', :b => 'b'}, B.new.config.to_hash)
    assert_equal({:a => 'a', :b => 'B', :c => 'C'}, C.new.config.to_hash)

    ###
    c = NestingClass.new
    assert_equal({:one => 'one', :two => {:three => 'three'}}, c.config.to_hash)
  
    c.two.three = 'THREE'
    assert_equal 'THREE', c.config[:two][:three]
  
    ###
    alt = AlternativeClass.new
    assert_equal false, alt.respond_to?(:sym)
    assert_equal false, alt.respond_to?(:sym=)
    
    alt.config[:sym] = 'one'
    assert_equal :one, alt.get_sym
  
    alt.set_sym('two')
    assert_equal :two, alt.config[:sym]
  
    ###
    assert_equal :upcase, AttributesClass.configurations[:a].type
    assert_equal :upcase, AttributesClass.configurations[:b].type
  end
  
  #
  # include test
  #
  
  class IncludeClass
    include Configurable
  end
  
  def test_include_extends_class_with_ClassMethods
    assert IncludeClass.kind_of?(Configurable::ClassMethods)
  end
   
  def test_extend_initializes_class_configurations
    assert_equal({}, IncludeClass.configurations)
  end
  
  #
  # config tests
  #

  class DeclarationClass
    include Configurable
    config :key, 'value'
  end
  
  def test_config_adds_configurations_to_class_configuration
    assert_equal [:key], DeclarationClass.configurations.keys
  end
  
  def test_config_generates_accessors
    obj = DeclarationClass.new
    assert obj.respond_to?(:key)
    assert obj.respond_to?(:key=)
    
    obj.key = 'VALUE'
    assert_equal 'VALUE', obj.key
  end
  
  class SelectClass
    include Configurable
    config :key, 'a', :options => %w{a b c}
  end
  
  def test_select_allows_any_of_the_values_in_options
    obj = SelectClass.new
    obj.key = 'a'
    assert_equal 'a', obj.key
    
    obj.key = 'c'
    assert_equal 'c', obj.key
  end
  
  def test_select_config_raises_error_if_value_is_not_in_options
    obj = SelectClass.new
    err = assert_raises(ArgumentError) { obj.key = 'z' }
    assert_equal 'invalid value for key: "z"', err.message
  end
  
  class ListClass
    include Configurable
    config :key, []
  end
  
  def test_list_an_array_of_values
    obj = ListClass.new
    
    obj.key = [1, 2, 3]
    assert_equal [1, 2, 3], obj.key
    
    obj.key = []
    assert_equal [], obj.key
  end
  
  def test_list_config_raises_error_for_non_array_values
    obj = ListClass.new
    err = assert_raises(ArgumentError) { obj.key = 'str'}
    assert_equal 'invalid value for key: "str"', err.message
  end
  
  class ListSelectClass
    include Configurable
    config :key, [], :options => %w{a b c}
  end
  
  def test_list_select_allows_an_array_composed_of_values_in_options
    obj = ListSelectClass.new
    
    obj.key = ['a', 'c', 'a']
    assert_equal ['a', 'c', 'a'], obj.key
    
    obj.key = []
    assert_equal [], obj.key
  end
  
  def test_list_select_config_raises_error_for_non_array_values
    obj = ListSelectClass.new
    err = assert_raises(ArgumentError) { obj.key = 'str'}
    assert_equal 'invalid value for key: "str"', err.message
  end
  
  def test_list_select_config_raises_error_for_array_values_not_in_options
    obj = ListSelectClass.new
    err = assert_raises(ArgumentError) { obj.key = ['z']}
    assert_equal 'invalid value for key: ["z"]', err.message
  end
  
  def test_config_raises_error_for_non_symbol_keys
    err = assert_raises(RuntimeError) { DeclarationClass.send(:config, 'key') }
    assert_equal 'invalid name: "key" (not a Symbol)', err.message
  end
  
  def test_config_raises_error_for_non_word_characters_in_key
    err = assert_raises(NameError) { DeclarationClass.send(:config, :'k,ey') }
    assert_equal 'invalid characters in name: :"k,ey"', err.message
  end
  
  #
  # config cast test
  #
  
  class StringCastClass
    include Configurable
    config :key, 'abc'
  end
  
  def test_config_does_not_cast_strings
    obj = StringCastClass.new
    obj.key = 'xyz'
    assert_equal 'xyz', obj.key
  end
  
  class IntegerCastClass
    include Configurable
    config :key, 1
  end
  
  def test_config_casts_integers
    obj = IntegerCastClass.new
    obj.key = '2'
    assert_equal 2, obj.key
    
    err = assert_raises(ArgumentError) { obj.key = 'abc' }
    assert_equal 'invalid value for Integer: "abc"', err.message
  end
  
  class FloatCastClass
    include Configurable
    config :key, 1.2
  end
  
  def test_config_casts_floats
    obj = FloatCastClass.new
    obj.key = '2.1'
    assert_equal 2.1, obj.key
    
    err = assert_raises(ArgumentError) { obj.key = 'abc' }
    assert_equal 'invalid value for Float(): "abc"', err.message
  end
  
  class BooleanCastClass
    include Configurable
    config :key, true
  end
  
  def test_config_casts_boolean
    obj = BooleanCastClass.new
    obj.key = 'true'
    assert_equal true, obj.key
    
    obj.key = 'false'
    assert_equal false, obj.key
    
    err = assert_raises(ArgumentError) { obj.key = 'abc' }
    assert_equal 'invalid value for boolean: "abc"', err.message
  end
  
  #
  # nest test
  #
  
  class NestA
    include Configurable
  
    config :key, 'one'
    nest :nest do
      config :key, 'two'
    end
  end
  
  class NestB
    include Configurable
  
    config :key, 1
    nest :nest do 
      config :key, 2
      nest :nest do
        config :key, 3
      end
    end
  end
  
  class NestC
    include Configurable
    nest :a, NestA
    nest :b, NestB
  end
  
  def test_nest_usage
    a = NestA.new
    assert_equal 'one', a.key
    assert_equal 'one', a.config[:key]
  
    assert_equal 'two', a.nest.key
    assert_equal 'two', a.config[:nest][:key]
  
    a.nest.key = 'TWO'
    assert_equal 'TWO', a.config[:nest][:key]
  
    a.config[:nest][:key] = 'too'
    assert_equal 'too', a.nest.key
  
    assert_equal({:key => 'one', :nest => {:key => 'too'}}, a.config.to_hash)
    assert_equal({:key => 'too'}, a.nest.config.to_hash)
    assert_equal NestA::Nest, a.nest.class
  
    c = NestC.new
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
  # nest config
  #
  
  class NestChild
    include Configurable
    config :key, 'value'
  end
  
  class NestParent
    include Configurable
    
    def initialize(overrides={})
      initialize_config(overrides)
    end
    
    nest :nest, NestChild
  end
  
  def test_nest_initializes_instance_of_nested_configurable_class
    p = NestParent.new
    assert_equal NestChild, p.nest.class
  end
  
  def test_nest_creates_accessor_for_nest_config
    methods = NestParent.public_instance_methods.collect {|m| m.to_sym }
    assert methods.include?(:nest)
    assert methods.include?(:nest=)
  end
  
  class NestWithoutAccessors
    include Configurable
    nest :no_reader, :reader => :alt
    nest :no_writer, :writer => :alt
  end
  
  def test_nest_does_not_create_accessors_if_alternates_are_specified
    methods = NestWithoutAccessors.public_instance_methods.collect {|m| m.to_sym }
    assert !methods.include?(:no_reader)
    assert methods.include?(:no_reader=)
    
    assert methods.include?(:no_writer)
    assert !methods.include?(:no_writer=)
  end
  
  def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
    p = NestParent.new
    assert_equal({:key => 'value'}, p.nest.config.to_hash)
    
    p.config[:nest][:key] = 'zero'
    assert_equal({:key => 'zero'}, p.nest.config.to_hash)
    
    p.config[:nest] = {:key => 'two'}
    assert_equal({:key => 'two'}, p.nest.config.to_hash)
      
    p.nest.key = "two"
    assert_equal({:key => 'two'}, p.config[:nest].to_hash)
    
    p.nest.config.merge!(:key => 'one')
    assert_equal({:key => 'one'}, p.config[:nest].to_hash)
    
    p.nest.config[:key] = 'zero'
    assert_equal({:key => 'zero'}, p.config[:nest].to_hash)
  end
  
  def test_parent_is_initialized_with_defaults
    p = NestParent.new 
    assert_equal({:nest => {:key => 'value'}}, p.config.to_hash)
    assert_equal({:key => 'value'}, p.nest.config.to_hash)
  end
  
  def test_parent_is_initialized_with_overrides
    p = NestParent.new :nest => {:key => 'one'}
    assert_equal({:nest => {:key => 'one'}}, p.config.to_hash)
    assert_equal({:key => 'one'}, p.nest.config.to_hash)
  end
  
  def test_parent_instance_may_be_specified_as_config_value
    c = NestChild.new
    p = NestParent.new :nest => c
    assert_equal c.object_id, p.nest.object_id
  end
  
  def test_parent_writer_is_validated
    p = NestParent.new
    obj = Object.new 
    err = assert_raises(ArgumentError) { p.nest = obj }
    assert_equal "invalid value for nest: #{obj.inspect}", err.message
  end
  
  #
  # recursive nest test
  #
  
  class RecursiveNest
    include Configurable
    
    def initialize(overrides={})
      initialize_config(overrides)
    end
    
    config :key, 'a'
    nest :nest do
      config :key, 'b'
      nest :nest do
        config :key, 'c'
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
  
  def test_recursive_nests_initializes_overrides_correctly
    r = RecursiveNest.new(
      :key => 'one', 
      :nest => {
        :key => 'two', 
        :nest => {
          :key => 'three'
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
  
  #
  # modules test
  #
  
  module ConfigModule
    include Configurable
    config :key, 'value'
  end
  
  def test_configurations_may_be_declared_in_modules
    assert_equal [:key], ConfigModule.configurations.keys
  end
  
  class IncludingConfigModule
    include ConfigModule
  end
  
  def test_module_configurations_are_added_to_class_on_include
    obj = IncludingConfigModule.new
    assert_equal({:key => 'value'}, obj.config.to_hash)
  end
  
  module ConfigModuleA
    include Configurable
    config :a, 'one'
  end
  
  module ConfigModuleB
    include ConfigModuleA
    config :b, 'two'
  end
  
  module ConfigModuleC
    include Configurable
    config :c, 'three'
  end
  
  class MultiIncludingConfigModule
    include ConfigModuleB
    include ConfigModuleC
  end
  
  def test_multiple_modules_may_be_added_to_class_on_include
    obj = MultiIncludingConfigModule.new
    assert_equal({
      :a => 'one',
      :b => 'two',
      :c => 'three'
    }, obj.config.to_hash)
  end
  
  class IncludingConfigModuleInExistingConfigurable
    include Configurable
    include ConfigModuleB
    include ConfigModuleC
    
    config :b, 'TWO'
    config :d, 'four'
  end
  
  def test_modules_may_be_added_to_an_existing_configurable_class
    obj = IncludingConfigModuleInExistingConfigurable.new
    assert_equal({
      :a => 'one',
      :b => 'TWO',
      :c => 'three',
      :d => 'four'
    }, obj.config.to_hash)
  end
  
  #
  # config_type test
  #
  
  class ConfigTypeClass
    include Configurable
    config_type(:upcase) {|input| input.upcase }
    config :key, 'abc', :type => :upcase
  end
  
  def test_config_type_registers_a_casting_type
    obj = ConfigTypeClass.new
    assert_equal 'ABC', obj.key
    
    obj.key = 'xyz'
    assert_equal 'XYZ', obj.key
  end
  
  class ConfigTypeParent
    include Configurable
    config_type(:upcase) {|input| input.upcase }
  end
  
  module ConfigTypeModule
    include Configurable
    config_type(:negate) {|input| input * -1 }
  end
  
  class ConfigTypeChild < ConfigTypeParent
    include ConfigTypeModule
    config :one, 'abc', :type => :upcase
    config :two, 1, :type => :negate
  end
  
  def test_config_types_are_inherited
    obj = ConfigTypeChild.new
    assert_equal 'ABC', obj.one
    assert_equal(-1, obj.two)
    
    obj.one = 'xyz'
    assert_equal 'XYZ', obj.one
    
    obj.two = -10
    assert_equal 10, obj.two
  end
  
  class ConfigTypeFloatParent
    include Configurable
    config :one, 'aBc'
  end
  
  class ConfigTypeFloatChild < ConfigTypeFloatParent
    config_type(:upcase) {|input| input.upcase }
  end
  
  def test_config_types_do_not_float_up
    assert_equal nil, ConfigTypeFloatParent.config_types[:upcase]
  end
  
  #
  # remove_config test
  #
  
  class RemoveConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_remove_config_removes_reader_and_writer_methods_if_specified
    c = RemoveConfig.new
    assert_equal 'a', c.a
    assert_equal 'b', c.b
    
    RemoveConfig.send(:remove_config, :a)
    assert_equal([:b], RemoveConfig.configurations.keys)
    assert !c.respond_to?(:a)
    assert !c.respond_to?(:a=)
    
    RemoveConfig.send(:remove_config, :b, :reader => false, :writer => false)
    assert_equal([], RemoveConfig.configurations.keys)
    assert c.respond_to?(:b)
    assert c.respond_to?(:b=)
  end
  
  class CachedRemoveConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_remove_config_resets_configurations
    assert_equal([:a, :b], CachedRemoveConfig.configurations.keys.sort_by {|key| key.to_s })
    CachedRemoveConfig.send(:remove_config, :a)
    assert_equal([:b], CachedRemoveConfig.configurations.keys)
  end
  
  #
  # undef_config test
  #
  
  class UndefConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_undef_config_removes_reader_and_writer_methods_if_specified
    c = UndefConfig.new
    assert_equal 'a', c.a
    assert_equal 'b', c.b
    
    UndefConfig.send(:undef_config, :a)
    assert_equal([:b], UndefConfig.configurations.keys)
    assert !c.respond_to?(:a)
    assert !c.respond_to?(:a=)
    
    UndefConfig.send(:undef_config, :b, :reader => false, :writer => false)
    assert_equal([], UndefConfig.configurations.keys)
    assert c.respond_to?(:b)
    assert c.respond_to?(:b=)
  end
  
  class CachedUndefConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_undef_config_resets_configurations
    assert_equal([:a, :b], CachedUndefConfig.configurations.keys.sort_by {|key| key.to_s })
    CachedUndefConfig.send(:undef_config, :a)
    assert_equal([:b], CachedUndefConfig.configurations.keys)
  end
  
#   #
#   # parse test
#   #
#   
#   class ParseClass
#     include Configurable
#     config(:one, 'one') {|v| v.upcase }
#   end
#   
#   def test_parse_parses_configs_from_argv
#     args, config = ParseClass.parse("a b --one value c")
#     assert_equal ["a", "b", "c"], args
#     assert_equal({:one => 'value'}, config)
#   end
#   
#   def test_parse_is_non_destructive_to_argv
#     argv = ["a", "b", "--one", "value", "c"]
#     ParseClass.parse(argv)
#     assert_equal ["a", "b", "--one", "value", "c"], argv
#   end
#   
#   def test_parse_bang_is_destructive_to_argv
#     argv = ["a", "b", "--one", "value", "c"]
#     ParseClass.parse!(argv)
#     assert_equal ["a", "b", "c"], argv
#   end
  
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
  
  def test_baseclass_is_not_affected_by_inheritance
    obj = IncludeBase.new
    assert_equal({:one => 'one'}, obj.config.to_hash)
  end
    
  def test_subclasses_inherit_configurations
    obj = IncludeSubclass.new
    assert_equal({
      :one => 'one',
      :two => 'two'
    }, obj.config.to_hash)
  end
  
  def test_subclasses_inherit_accessors
    obj = IncludeSubclass.new
    assert obj.respond_to?(:one)
    assert obj.respond_to?(:one=)
  end
  
  def test_inherited_configurations_can_be_overridden
    obj = OverrideSubclass.new
    assert_equal({:one => 'ONE'}, obj.config.to_hash)
  end
  
  #
  # lazydoc test
  #
  
  class LazydocNestClass
    include Configurable
  end
  
  class LazydocClass
    include Configurable
  
    config :one, 'value'                                  # one with documentation
    config :two, 'value', :desc => "two description"      # two ignored documentation
    config :three, 'value',                               # three with offset documentation
      :a => 'a',
      :b => 'b'
  end
  
  def test_configurable_registers_configs_with_lazydoc_unless_desc_is_specified
    desc = LazydocClass.configurations[:one].desc
    assert_equal "one with documentation", desc.to_s
    
    desc = LazydocClass.configurations[:two].desc
    assert_equal "two description", desc.to_s
    
    desc = LazydocClass.configurations[:three].desc
    assert_equal "three with offset documentation", desc.to_s
  end
  
  module LazydocConfigModule
    include Configurable

    config :one, 'value'                             # one with documentation
    config :two, 'value', :desc => "two description" # two ignored documentation
  end
  
  class LazydocIncludeClass
    include LazydocConfigModule
    
    config :three, 'value'                                # three with documentation
    config :four, 'value', :desc => "four description"    # four ignored documentation
  end
  
  def test_configurable_registers_documentation_for_configs_in_modules
    [:one, :three].each do |name|
      desc = LazydocIncludeClass.configurations[name].desc
      assert_equal "#{name} with documentation", desc.to_s
    end
    
    [:two, :four].each do |name|
      desc = LazydocIncludeClass.configurations[name].desc
      assert_equal "#{name} description", desc.to_s
    end
  end
  
  #
  # initialize test
  #
  
  class InitializeClass
    include Configurable
    config :key, 'value'
  end
  
  def test_initialize_initializes_config_if_necessary
    obj = InitializeClass.new
    assert_equal ConfigHash, obj.config.class
    assert_equal({:key => 'value'}, obj.config.to_hash)
  end
  
  class NoInitializeClass
    include Configurable
    config :key, 'value'
    
    def initialize
      @config = {:key => 'alt'}
      super
    end
  end
  
  def test_initialize_does_not_override_existing_config
    obj = NoInitializeClass.new
    assert_equal Hash, obj.config.class
    assert_equal({:key => 'alt'}, obj.config)
  end
  
  #
  # initialize_config test
  #
  
  class Sample
    include Configurable
    
    def initialize(overrides={})
      initialize_config(overrides)
    end
    
    config :one, 'one'
    config :two, 'two'
  end
  
  def test_initialize_config_merges_class_defaults_with_overrides
    obj = Sample.new(:two => 'TWO')
    assert_equal({:one => 'one', :two => 'TWO'}, obj.config.to_hash)
  end
  
  #
  # initialize_copy test
  #
  
  def test_duplicates_have_an_independent_config
    orig = Sample.new
    copy = orig.dup
    
    assert orig.config.object_id != copy.config.object_id
    
    orig.two = 'TWO'
    copy.two = 'two'
    assert_equal 'TWO', orig.two
    assert_equal 'two', copy.two
    
    orig.config[:three] = 'THREE'
    copy.config[:three] = 'three'
    assert_equal 'THREE', orig.config[:three]
    assert_equal 'three', copy.config[:three]
  end
  
  def test_dup_passes_along_current_config_values
    orig = Sample.new
    orig.two = 'TWO'
    orig.config[:three] = 'THREE'
    assert_equal({:one => 'one', :two => 'TWO', :three => 'THREE'}, orig.config.to_hash)
    
    copy = orig.dup
    assert_equal({:one => 'one', :two => 'TWO', :three => 'THREE'}, copy.config.to_hash)
  end
  
  class NonInitSample
    include Configurable
    config :key, 'default', :init => false
  end
  
  def test_dup_passes_along_non_init_configs
    orig = NonInitSample.new
    orig.key = 'value'
    assert_equal({:key => 'value'}, orig.config.to_hash)
    
    copy = orig.dup
    assert_equal({:key => 'value'}, copy.config.to_hash)
  end
end
