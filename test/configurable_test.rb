require File.expand_path('../test_helper', __FILE__)
require 'configurable'
require 'tempfile'

class ConfigurableTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  ConfigHash = Configurable::ConfigHash
  
  #
  # include test
  #
  
  class IncludeClass
    include Configurable
  end
  
  def test_include_extends_class_with_ClassMethods
    assert IncludeClass.kind_of?(Configurable::ClassMethods)
  end
  
  def test_include_does_not_pollute_namespaces
    assert_equal false, IncludeClass.const_defined?(:Config)
    assert_equal false, IncludeClass.class.const_defined?(:Config)
  end
  
  def test_extend_initializes_class_configs
    assert_equal({}, IncludeClass.configs)
  end
  
  #
  # modules test
  #
  
  module ConfigModule
    include Configurable
    config :key, 'value'
  end
  
  def test_configs_may_be_declared_in_modules
    assert_equal [:key], ConfigModule.configs.keys
  end
  
  class IncludingConfigModule
    include ConfigModule
  end
  
  def test_module_configs_are_added_to_class_on_include
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
  # config_types test
  #
  
  class ConfigTypeClass
    include Configurable
    config_type(:upcase, :option_type => :option) {|input| input.upcase }
    config :key, 'abc', :type => :upcase
  end
  
  def test_config_type_registers_a_config_type
    config_type = ConfigTypeClass.config_types[:upcase]
    assert_equal 'XYZ', config_type.default_attrs[:caster].call('xyz')
    assert_equal :option, config_type.default_attrs[:option_type]
    
    assert_equal 'XYZ', ConfigTypeClass.configs[:key].cast('xyz')
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
    config = ConfigTypeChild.configs[:one]
    assert_equal 'XYZ', config.cast('xyz')
    
    config = ConfigTypeChild.configs[:two]
    assert_equal 8, config.cast(-8)
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
    assert_equal([:b], RemoveConfig.configs.keys)
    assert !c.respond_to?(:a)
    assert !c.respond_to?(:a=)
    
    RemoveConfig.send(:remove_config, :b, :reader => false, :writer => false)
    assert_equal([], RemoveConfig.configs.keys)
    assert c.respond_to?(:b)
    assert c.respond_to?(:b=)
  end
  
  class CachedRemoveConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_remove_config_resets_configs
    assert_equal([:a, :b], CachedRemoveConfig.configs.keys.sort_by {|key| key.to_s })
    CachedRemoveConfig.send(:remove_config, :a)
    assert_equal([:b], CachedRemoveConfig.configs.keys)
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
    assert_equal([:b], UndefConfig.configs.keys)
    assert !c.respond_to?(:a)
    assert !c.respond_to?(:a=)
    
    UndefConfig.send(:undef_config, :b, :reader => false, :writer => false)
    assert_equal([], UndefConfig.configs.keys)
    assert c.respond_to?(:b)
    assert c.respond_to?(:b=)
  end
  
  class CachedUndefConfig
    include Configurable
    config :a, 'a'
    config :b, 'b'
  end
  
  def test_undef_config_resets_configs
    assert_equal([:a, :b], CachedUndefConfig.configs.keys.sort_by {|key| key.to_s })
    CachedUndefConfig.send(:undef_config, :a)
    assert_equal([:b], CachedUndefConfig.configs.keys)
  end
  
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
    
  def test_subclasses_inherit_configs
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
  
  def test_inherited_configs_can_be_overridden
    obj = OverrideSubclass.new
    assert_equal({:one => 'ONE'}, obj.config.to_hash)
  end
  
  #
  # define_config tests
  #

  class DefineConfigClass
    include Configurable
    define_config :key
  end

  def test_define_config_registers_config
    assert_equal [:key], DefineConfigClass.configs.keys
  end

  def test_define_config_generates_accessors
    obj = DefineConfigClass.new
    assert obj.respond_to?(:key)
    assert obj.respond_to?(:key=)

    obj.key = 'VALUE'
    assert_equal 'VALUE', obj.key
  end

  class DefineConfigNoAccessorsClass
    include Configurable
    define_config :no_reader, :reader => :no_reader
    define_config :no_writer, :writer => :no_writer=
  end

  def test_define_config_does_not_generate_reader_if_reader_is_specified
    assert_equal false, DefineConfigNoAccessorsClass.instance_methods.include?('no_reader')
    assert_equal true, DefineConfigNoAccessorsClass.instance_methods.include?('no_reader=')
  end
  
  def test_define_config_does_not_generate_writer_if_writer_is_specified
    assert_equal true, DefineConfigNoAccessorsClass.instance_methods.include?('no_writer')
    assert_equal false, DefineConfigNoAccessorsClass.instance_methods.include?('no_writer=')
  end
  
  #
  # config test
  #
  
  class ConfigWithTypeClass
    include Configurable
    config_type(:upcase) {|value| value.upcase }
    config :key, 'XYZ', :type => :upcase
  end

  def test_config_resolves_config_type_if_possible
    assert_equal 'ABC', ConfigWithTypeClass.configs[:key].cast('abc')
  end
  
  class ConfigClass
    include Configurable
    config :key, :default
  end

  def test_config_sets_default_as_specified
    assert_equal :default, ConfigClass.configs[:key].default
  end
  
  class ConfigAttrsClass
    include Configurable
    config :key, :default, :short => :s
  end

  def test_config_sets_attrs_as_specified
    assert_equal :s, ConfigAttrsClass.configs[:key][:short]
  end
  
  class ConfigCasterClass
    include Configurable
    config(:key, 'XYZ') {|value| value.upcase }
  end

  def test_config_sets_caster_to_block_if_specified
    assert_equal 'ABC', ConfigCasterClass.configs[:key].cast('abc')
  end
  
  class ListClass
    include Configurable
    config :key, []
  end
  
  def test_array_default_generates_a_list_config
    config = ListClass.configs[:key]
    assert_equal List, config.class
  end
  
  #
  # config cast test
  #
  
  class StringCastClass
    include Configurable
    config :key, 'abc'
  end
  
  def test_config_stringifies_strings
    config = StringCastClass.configs[:key]
    assert_equal 'xyz', config.cast(:xyz)
  end
  
  class IntegerCastClass
    include Configurable
    config :key, 1
  end
  
  def test_config_casts_integers
    config = IntegerCastClass.configs[:key]
    assert_equal 2, config.cast('2')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for Integer: "abc"', err.message
  end
  
  class FloatCastClass
    include Configurable
    config :key, 1.2
  end
  
  def test_config_casts_floats
    config = FloatCastClass.configs[:key]
    assert_equal 2.1, config.cast('2.1')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for Float(): "abc"', err.message
  end
  
  class BooleanCastClass
    include Configurable
    config :key, true
  end
  
  def test_config_casts_boolean
    config = BooleanCastClass.configs[:key]
    assert_equal true, config.cast('true')
    assert_equal false, config.cast('false')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for boolean: "abc"', err.message
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
    desc = LazydocClass.configs[:one][:desc]
    assert_equal "one with documentation", desc.to_s
    
    desc = LazydocClass.configs[:two][:desc]
    assert_equal "two description", desc.to_s
    
    desc = LazydocClass.configs[:three][:desc]
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
      desc = LazydocIncludeClass.configs[name][:desc]
      assert_equal "#{name} with documentation", desc.to_s
    end
    
    [:two, :four].each do |name|
      desc = LazydocIncludeClass.configs[name][:desc]
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
