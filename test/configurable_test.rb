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
    caster(:upcase) {|v| v.upcase }
    config(:one, 'one', :caster => :upcase)
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
    caster(:upcase) {|v| v.upcase }

    config :a, 'A', :caster => :upcase
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
  # casters test
  #
  
  class CasterClass
    include Configurable
    caster(:upcase) {|input| input.upcase }
    config :key, 'abc', :caster => :upcase
  end
  
  def test_caster_registers_a_casting_type
    caster = CasterClass.casters[:upcase]
    assert_equal 'XYZ', caster.call('xyz')
    assert_equal 'XYZ', CasterClass.configs[:key].cast('xyz')
  end
  
  class CasterParent
    include Configurable
    caster(:upcase) {|input| input.upcase }
  end
  
  module CasterModule
    include Configurable
    caster(:negate) {|input| input * -1 }
  end
  
  class CasterChild < CasterParent
    include CasterModule
    config :one, 'abc', :caster => :upcase
    config :two, 1, :caster => :negate
  end
  
  def test_casters_are_inherited
    config = CasterChild.configs[:one]
    assert_equal 'XYZ', config.cast('xyz')
    
    config = CasterChild.configs[:two]
    assert_equal 10, config.cast(-10)
  end
  
  class CasterFloatParent
    include Configurable
    config :one, 'aBc'
  end
  
  class CasterFloatChild < CasterFloatParent
    caster(:upcase) {|input| input.upcase }
  end
  
  def test_casters_do_not_float_up
    assert_equal nil, CasterFloatParent.casters[:upcase]
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
  # parse test
  #
  
  class ParseClass
    include Configurable
    config(:one, 'one') {|v| v.upcase }
  end
  
  def test_parse_parses_configs_from_argv_without_casting
    args, config = ParseClass.parse("a b --one value c")
    assert_equal ["a", "b", "c"], args
    assert_equal({:one => 'value'}, config)
  end
  
  def test_parse_is_non_destructive_to_argv
    argv = ["a", "b", "--one", "value", "c"]
    ParseClass.parse(argv)
    assert_equal ["a", "b", "--one", "value", "c"], argv
  end
  
  def test_parse_bang_is_destructive_to_argv
    argv = ["a", "b", "--one", "value", "c"]
    ParseClass.parse!(argv)
    assert_equal ["a", "b", "c"], argv
  end
  
  #
  # extract test
  #
  
  class ExtractClass
    include Configurable
    config(:one)
  end
  
  def test_extract_maps_config_names_to_config_keys
    assert_equal({
      :one => 'NAME'
    }, ExtractClass.extract(:one => 'KEY', 'one' => 'NAME'))
  end
  
  def test_extract_maps_ignores_unknown_keys
    assert_equal({}, ExtractClass.extract(:unknown => 'value'))
  end
  
  class NestExtractClass
    include Configurable
    config(:one)
    nest(:nest) do
      config(:two)
    end
  end
  
  def test_extract_recursively_extracts_values_for_nested_configs
    source = {
      'one' => 'ONE',
      'nest' => {'two' => 'TWO'}
    }
    
    target = {
      :one => 'ONE',
      :nest => {:two => 'TWO'}
    }
    
    assert_equal(target, NestExtractClass.extract(source))
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
