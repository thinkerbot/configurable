require File.expand_path('../test_helper', __FILE__)
require 'configurable'
require 'tempfile'

class ConfigurableTest < Test::Unit::TestCase
  include Configurable::ConfigClasses
  include Configurable::ConfigTypes
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
    assert_equal false, IncludeClass.const_defined?(:ScalarConfig)
    assert_equal false, IncludeClass.class.const_defined?(:ScalarConfig)
  end
  
  def test_extend_initializes_registries
    assert_equal({}, IncludeClass.config_registry)
    assert_equal({}, IncludeClass.config_type_registry)
  end
  
  #
  # define_config tests
  #

  class DefineConfigClass
    include Configurable
    define_config :key
  end

  def test_define_config_initializes_and_registers_config
    assert_equal [:key], DefineConfigClass.configs.keys
    assert_equal ScalarConfig, DefineConfigClass.configs[:key].class
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
  
  class ConfigClass
    include Configurable
    config :key, :default
  end

  def test_config_defines_a_scalar_config_with_default
    config = ConfigClass.configs[:key]
    assert_equal :default, config.default
    assert_equal ScalarConfig, config.class
  end
  
  #
  # config type test
  #
  
  class ConfigStringTypeClass
    include Configurable
    config :key, 'abc'
  end
  
  def test_config_gueses_string_type_for_string_default
    config = ConfigStringTypeClass.configs[:key]
    assert_equal 'xyz', config.cast(:xyz)
  end
  
  class ConfigIntegerTypeClass
    include Configurable
    config :key, 1
  end
  
  def test_config_guesses_integer_type_for_integer_default
    config = ConfigIntegerTypeClass.configs[:key]
    assert_equal 2, config.cast('2')
    assert_equal 2, config.cast(2.1)
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_match(/invalid value for Integer/, err.message)
  end
  
  class ConfigFloatTypeClass
    include Configurable
    config :key, 1.2
  end
  
  def test_config_guesses_float_type_for_float_default
    config = ConfigFloatTypeClass.configs[:key]
    assert_equal 2.1, config.cast('2.1')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for Float(): "abc"', err.message
  end
  
  class ConfigBooleanTypeClass
    include Configurable
    config :flag, true
    config :switch, false
  end
  
  def test_config_guesses_boolean_type_for_true_default
    config = ConfigBooleanTypeClass.configs[:flag]
    assert_equal true,  config.cast('true')
    assert_equal false, config.cast('false')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for boolean: "abc"', err.message
  end
  
  def test_config_guesses_boolean_type_for_false_default
    config = ConfigBooleanTypeClass.configs[:switch]
    assert_equal true,  config.cast('true')
    assert_equal false, config.cast('false')
  
    err = assert_raises(ArgumentError) { config.cast('abc') }
    assert_equal 'invalid value for boolean: "abc"', err.message
  end
  
  class ConfigWithTypeClass
    include Configurable
    config :int, 1, :type => :float
  end

  def test_config_uses_specified_config_type
    config = ConfigWithTypeClass.configs[:int]
    assert_equal 1.1, config.cast(1.1)
  end
  
  #
  # list config test
  #
  
  class ListConfigClass
    include Configurable
    config :key, []
  end
  
  def test_config_generates_a_list_config_for_array_default
    config = ListConfigClass.configs[:key]
    assert_equal ListConfig, config.class
  end
  
  class ListConfigWithIntegerTypeClass
    include Configurable
    config :key, [1,2,3]
  end
  
  def test_list_configs_guess_type_from_array_entries
    config = ListConfigWithIntegerTypeClass.configs[:key]
    assert_equal [8, 9, 10], config.cast(['8', 9, '10'])
  end
  
  #
  # nest config test
  #
  
  class NestConfigFromConfigurableClass
    include Configurable
    
    class Outer
      include Configurable
      config :inner, 1
    end
    
    config :outer, Outer.new
  end
  
  def test_config_generates_a_nest_config_for_configurable_default
    config = NestConfigFromConfigurableClass.configs[:outer]
    assert_equal NestConfig, config.class
    assert_equal NestConfigFromConfigurableClass::Outer, config.type.configurable.class
    assert_equal({:inner => 1}, config.cast({'inner' => '1'}))
  end
  
  class NestConfigFromHashClass
    include Configurable
    config :outer, {:inner => 1}
  end
  
  def test_config_generates_a_nest_config_and_configurable_class_for_hash_default
    config = NestConfigFromHashClass.configs[:outer]
    assert_equal NestConfig, config.class
    assert_equal NestConfigFromHashClass::Outer, config.type.configurable.class
    assert_equal({:inner => 1}, config.cast({'inner' => '1'}))
  end
  
  class NestConfigFromBlockClass
    include Configurable
    config :outer do 
      config :inner, 1
    end
  end
  
  def test_config_generates_a_nest_config_and_configurable_class_for_block
    config = NestConfigFromBlockClass.configs[:outer]
    assert_equal NestConfig, config.class
    assert_equal NestConfigFromBlockClass::Outer, config.type.configurable.class
    assert_equal({:inner => 1}, config.cast({'inner' => '1'}))
  end
  
  #
  # config metadata test
  #
  
  class ConfigWithMetaDataClass
    include Configurable
    config :key, :default, :short => :s
  end

  def test_config_sets_attrs_into_metadata
    assert_equal :s, ConfigWithMetaDataClass.configs[:key][:short]
  end
  
  def test_config_does_not_put_guessed_attrs_into_metadata
    config = ConfigWithMetaDataClass.configs[:key]
    assert_equal nil, config[:type]
    assert_equal nil, config[:metadata]
  end
  
  class ConfigDocClass
    include Configurable
  
    config :one, 'value'                   # one
    config :two, 'value', :desc => "TWO"   # two
    config :three, 'value',                # three
      :a => 'a',
      :b => 'b'
  end
  
  def test_config_extracts_desc_from_documentation_unless_specified
    assert_equal "one",   ConfigDocClass.configs[:one][:desc]
    assert_equal "TWO",   ConfigDocClass.configs[:two][:desc]
    assert_equal "three", ConfigDocClass.configs[:three][:desc]
  end
  
  module DocConfigModule
    include Configurable

    config :one, 'value'                   # one
    config :two, 'value', :desc => "TWO"   # two
  end
  
  class DocIncludeClass
    include DocConfigModule
    
    config :three, 'value'                 # three
    config :four, 'value', :desc => "FOUR" # four
  end
  
  def test_configurable_registers_documentation_for_configs_in_modules
    [:one, :three].each do |name|
      assert_equal name.to_s, DocIncludeClass.configs[name][:desc]
    end
    
    [:two, :four].each do |name|
      assert_equal name.to_s.upcase, DocIncludeClass.configs[name][:desc]
    end
  end
  
  class DocSyntaxClass
    include Configurable
  
    config :a  # none
    config :b  # -t, --two       : short and long
    config :c  #     --three     : long only
    config :d  # -f              : short only
    config :e  #     --five FIVE : argname
    config :f  # --no-desc, -s   :
  end
  
  def test_configurable_extracts_long_and_short_metadata_from_documentation
    assert_equal nil, DocSyntaxClass.configs[:a][:short]
    assert_equal nil, DocSyntaxClass.configs[:a][:long]
    assert_equal nil, DocSyntaxClass.configs[:a][:arg_name]
    
    assert_equal '-t',    DocSyntaxClass.configs[:b][:short]
    assert_equal '--two', DocSyntaxClass.configs[:b][:long]
    assert_equal nil,     DocSyntaxClass.configs[:b][:arg_name]
    
    assert_equal nil,       DocSyntaxClass.configs[:c][:short]
    assert_equal '--three', DocSyntaxClass.configs[:c][:long]
    assert_equal nil,       DocSyntaxClass.configs[:c][:arg_name]
    
    assert_equal '-f', DocSyntaxClass.configs[:d][:short]
    assert_equal nil,  DocSyntaxClass.configs[:d][:long]
    assert_equal nil,  DocSyntaxClass.configs[:d][:arg_name]
    
    assert_equal  nil,     DocSyntaxClass.configs[:e][:short]
    assert_equal '--five', DocSyntaxClass.configs[:e][:long]
    assert_equal 'FIVE',   DocSyntaxClass.configs[:e][:arg_name]
    
    assert_equal '-s',        DocSyntaxClass.configs[:f][:short]
    assert_equal '--no-desc', DocSyntaxClass.configs[:f][:long]
    assert_equal nil,         DocSyntaxClass.configs[:f][:arg_name]
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
  # config_types test
  #
  
  class ConfigTypeClass
    include Configurable
    config_type(:upcase) {|input| input.upcase }
    config :key, 'abc', :type => :upcase
  end
  
  def test_config_type_registers_a_config_type
    config_type = ConfigTypeClass.config_types[:upcase]
    assert_equal 'XYZ', ConfigTypeClass.configs[:key].cast('xyz')
  end
  
  def test_config_type_sets_the_new_config_type_to_a_const
    assert_equal ConfigTypeClass::UpcaseType, ConfigTypeClass.config_types[:upcase]
  end
  
  class ConfigTypeAlreadySet
    include Configurable
    class ExistsType; end
    config_type :exists
  end
  
  def test_config_type_does_not_set_config_type_const_if_name_is_taken
    assert_equal "", ConfigTypeAlreadySet.config_types[:exists].name
  end
  
  class ConfigTypeCamelize
    include Configurable
    config_type :camel_case
  end
  
  def test_config_type_guesses_correct_camel_case_constant
    assert_equal ConfigTypeCamelize::CamelCaseType, ConfigTypeCamelize.config_types[:camel_case]
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
  
  class ConfigTypeMatchClass
    include Configurable
    MatchClass = Struct.new(:input)
    
    config_type(:match, MatchClass) {|input| MatchClass.new(input) }
    config :key, MatchClass.new
  end
  
  def test_config_type_is_guessed_for_matching_instances
    config = ConfigTypeMatchClass.configs[:key]
    assert_equal ConfigTypeMatchClass::MatchType, config.type.class
    
    value = config.cast('input')
    assert_equal ConfigTypeMatchClass::MatchClass, value.class
    assert_equal 'input', value.input
  end
  
  module ConfigTypeSpecificity
    include Configurable
    
    # increase specificity for Bignum, over IntegerType
    config_type(:bignum, Bignum)
    
    config :one, 10**10
    config :two, 10**100
  end
  
  def test_config_types_can_increase_specificity
    assert_equal IntegerType, ConfigTypeSpecificity.configs[:one].type.class
    assert_equal ConfigTypeSpecificity::BignumType, ConfigTypeSpecificity.configs[:two].type.class
  end
  
  module ConfigTypeOverrideByMatch
    include Configurable
    
    # match integers, instead of IntegerType
    config_type(:num, Integer)
    config :one, 1
  end
  
  def test_config_types_can_be_overridden_by_match
    assert_equal ConfigTypeOverrideByMatch::NumType, ConfigTypeOverrideByMatch.configs[:one].type.class
  end
  
  module ConfigTypeOverrideByName
    include Configurable
    
    # match int type, instead of IntegerType
    config_type(:int)
    config :one, 1, :type => :int
  end
  
  def test_config_types_can_be_overridden_by_name
    assert_equal ConfigTypeOverrideByName::IntType, ConfigTypeOverrideByName.configs[:one].type.class
  end
  
  #
  # modules test
  #
  
  module ConfigModule
    include Configurable
    config :key, 'value'
  end
  
  def test_configs_may_be_declared_in_modules
    assert_equal({
      :key => 'value'
    }, ConfigModule.configs.to_default)
  end
  
  class IncludingConfigModule
    include ConfigModule
  end
  
  def test_module_configs_are_added_to_class_on_include
    assert_equal({
      :key => 'value'
    }, IncludingConfigModule.configs.to_default)
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
    assert_equal({
      :a => 'one',
      :b => 'two',
      :c => 'three'
    }, MultiIncludingConfigModule.configs.to_default)
  end
  
  class IncludingConfigModuleInExistingConfigurable
    include Configurable
    include ConfigModuleB
    include ConfigModuleC
    
    config :b, 'TWO'
    config :d, 'four'
  end
  
  def test_modules_may_be_added_to_an_existing_configurable_class
    assert_equal({
      :a => 'one',
      :b => 'TWO',
      :c => 'three',
      :d => 'four'
    }, IncludingConfigModuleInExistingConfigurable.configs.to_default)
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
    assert_equal({
      :one => 'one'
    }, IncludeBase.configs.to_default)
  end
    
  def test_subclasses_inherit_configs
    assert_equal({
      :one => 'one',
      :two => 'two'
    }, IncludeSubclass.configs.to_default)
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
