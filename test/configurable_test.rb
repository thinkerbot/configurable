require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'
require 'tempfile'

class ConfigurableTest < Test::Unit::TestCase
  Config = Configurable::Config
  ConfigHash = Configurable::ConfigHash
  Validation = Configurable::Validation
  
  # helper
  def assert_configurations_equal(expected, delegate)
    actual = delegate.inject({}) do |hash, (key, delegate)|
      hash[key] = [delegate.reader, delegate.writer, delegate.default]
      hash
    end
    
    assert_equal(expected, actual)
  end
  
  #
  # documentation test
  #
  
  class ConfigClass
    include Configurable
  
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  
  end
  
  class SubClass < ConfigClass
    config(:one, 'one') {|v| v.upcase }
    config :two, 2, &c.integer
  end
  
  class DocAlternativeClass
    include Configurable
  
    config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym
    
    def get_sym
      @sym
    end
  
    def set_sym(input)
      @sym = input.to_sym
    end
  end
  
  class DocAttributesClass 
    include Configurable
    block = c.register(:type => :upcase) {|v| v.upcase }

    config :a, 'A', &block
    config :b, 'B', &block
  end
  
  def test_documentation
    c = ConfigClass.new
    assert_equal(ConfigHash, c.config.class)
    assert_equal({:one => 'one', :two => 'two', :three => 'three'}, c.config)
  
    c.config[:one] = 'ONE'
    assert_equal 'ONE', c.one
  
    c.one = 1           
    assert_equal({:one => 1, :two => 'two', :three => 'three'}, c.config)
    
    c.config[:undeclared] = 'value'
    assert_equal({:undeclared => 'value'}, c.config.store)
  
    s = SubClass.new
    assert_equal({:one => 'ONE', :two => 2, :three => 'three'}, s.config)
    s.one = 'aNothER'             
    assert_equal 'ANOTHER', s.one
  
    s.two = -2
    assert_equal(-2, s.two)
    s.two = "3"
    assert_equal 3, s.two
    e = assert_raises(Validation::ValidationError) { s.two = nil }
    assert_equal "expected [Integer] but was: nil", e.message
    
    e = assert_raises(Validation::ValidationError) { s.two = 'str' }
    assert_equal "expected [Integer] but was: \"str\"", e.message
    
    alt = DocAlternativeClass.new
    assert_equal false, alt.respond_to?(:sym)
    assert_equal false, alt.respond_to?(:sym=)
    
    alt.config[:sym] = 'one'
    assert_equal :one, alt.get_sym
  
    alt.set_sym('two')
    assert_equal :two, alt.config[:sym]
    
    assert_equal :upcase, DocAttributesClass.configurations[:a][:type]
    assert_equal :upcase, DocAttributesClass.configurations[:b][:type]
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
  # config declaration tests
  #

  class DeclarationClass
    include Configurable
    
    def initialize(config={})
      initialize_config(config)
    end
    
    config_attr :zero, 'zero' do |value|
      @zero = value.upcase
      nil
    end
    
    config :one, 'one' do |value|
      value.upcase
    end
    
    config :two, 'two', :init => false
    
    config :three
  end
  
  def test_config_adds_configurations_to_class_configuration
    assert_configurations_equal({
      :zero =>  [:zero, :zero=, 'zero'],
      :one =>   [:one, :one=, 'one'],
      :two =>   [:two, :two=, 'two'],
      :three => [:three, :three=, nil]
    },
    DeclarationClass.configurations)
  end
  
  def test_config_generates_accessors
    t = DeclarationClass.new
    [:zero, :one, :two, :three].each do |config|
      assert t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
  end
  
  def test_config_reader_reads_instance_variable
    t = DeclarationClass.new
    assert_nil t.three
    t.instance_variable_set(:@three, 'three')
    assert_equal 'three', t.three
  end
  
  def test_config_writer_writes_instance_variable
    t = DeclarationClass.new
    assert_nil t.instance_variable_get(:@three)
    t.three = 'three'
    assert_equal 'three', t.instance_variable_get(:@three)
  end
  
  def test_config_with_block_uses_block_return_to_set_instance_variable
    t = DeclarationClass.new(:one => "one")
    assert_equal "ONE", t.one
    
    t.one = 'one'
    assert_equal 'ONE', t.one
    assert_equal 'ONE', t.instance_variable_get(:@one)
  end
  
  def test_config_with_init_false_will_not_initialize_from_configs
    t = DeclarationClass.new
    assert_equal false, t.instance_variable_defined?(:@two)
        
    err = assert_raises(RuntimeError) { DeclarationClass.new(:two => 2) }
    assert_equal "initialization values are not allowed for: :two", err.message
  end
  
  #
  # config_attr test
  #
  
  class ConfigAttrClass
    include Configurable
    
    def initialize
    end
    
    config_attr :trues, 'value', :reader => true, :writer => true
    config_attr :falses, 'value', :reader => false, :writer => false
  end
  
  def test_config_attr_reader_and_writer_true
    o = ConfigAttrClass.new
    assert o.respond_to?(:trues)
    assert o.respond_to?(:trues=)
    
    config = ConfigAttrClass.configurations[:trues]
    assert_equal :trues, config.reader
    assert_equal :trues=, config.writer
  end
  
  def test_config_attr_reader_and_writer_false
    o = ConfigAttrClass.new
    assert !o.respond_to?(:falses)
    assert !o.respond_to?(:falses=)
    
    config = ConfigAttrClass.configurations[:falses]
    assert_equal :falses, config.reader
    assert_equal :falses=, config.writer
  end
  
  class InvalidAttrClass
    include Configurable
  end
  
  def test_config_attr_reader_and_writer_cannot_be_nil
    e = assert_raises(RuntimeError) do
      InvalidAttrClass.send(:config, :a, 'value', :reader => nil)
    end
    assert_equal ":reader attribute cannot be nil", e.message

    e = assert_raises(RuntimeError) do
      InvalidAttrClass.send(:config, :b, 'value', :writer => nil)
    end
    assert_equal ":writer attribute cannot be nil", e.message
  end
  
  def test_block_without_writer_true_raises_error
    e = assert_raises(ArgumentError) { InvalidAttrClass.send(:config_attr, :a, 'val', :writer => :alt) {} }
    assert_equal "a block may not be specified without writer == true", e.message
    
    e = assert_raises(ArgumentError) { InvalidAttrClass.send(:config_attr, :b, 'val', :writer => false) {} }
    assert_equal "a block may not be specified without writer == true", e.message
  end
  
  class AttributesClass
    include Configurable
    
    config_attr :switch, true, :key => 'value', &c.switch
    config_attr :flag, false, :type => 'alt', &c.flag
  end
  
  def test_config_attr_merges_default_attributes
    switch = AttributesClass.configurations[:switch]
    assert_equal :switch, switch.attributes[:type]
    assert_equal 'value', switch.attributes[:key]

    flag = AttributesClass.configurations[:flag]
    assert_equal 'alt', flag.attributes[:type]
  end
  
  #
  # modules test
  #
  
  module ConfigModule
    include Configurable
    
    config :key, 'value'
  end
  
  def test_configurations_may_be_declared_in_modules
    assert_configurations_equal({
      :key =>  [:key, :key=, 'value']
    }, ConfigModule.configurations)
  end
  
  class IncludingConfigModule
    include ConfigModule
  end
  
  def test_module_configurations_are_added_to_class_on_include
    assert_configurations_equal({
      :key =>  [:key, :key=, 'value']
    }, IncludingConfigModule.configurations)
    
    c = IncludingConfigModule.new
    assert_equal 'value', c.key
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
    assert_configurations_equal({
      :a =>  [:a, :a=, 'one'],
      :b =>  [:b, :b=, 'two'],
      :c =>  [:c, :c=, 'three']
    }, MultiIncludingConfigModule.configurations)
    
    obj = MultiIncludingConfigModule.new
    assert_equal({
      :a => 'one',
      :b => 'two',
      :c => 'three'
    }, obj.config)
  end
  
  class IncludingConfigModuleInExistingConfigurable
    include Configurable
    include ConfigModuleB
    include ConfigModuleC
    
    config :b, 'TWO'
    config :d, 'four'
  end
  
  def test_modules_may_be_added_to_an_existing_configurable_class
    assert_configurations_equal({
      :a =>  [:a, :a=, 'one'],
      :b =>  [:b, :b=, 'TWO'],
      :c =>  [:c, :c=, 'three'],
      :d =>  [:d, :d=, 'four']
    }, IncludingConfigModuleInExistingConfigurable.configurations)
  end
  
  #
  # config context test
  #
  
  class ContextClass
    include Configurable
    
    class << self
      def context
        "Class"
      end
    end

    config :config_context do |value|
      context
    end
    
    config_attr :config_attr_context do |value|
      @config_attr_context = context
    end

    def context
      "Instance"
    end
  end
  
  def test_config_block_context_is_class
    c = ContextClass.new
    c.config_context = nil
    assert_equal "Class", c.config_context
  end
  
  def test_config_attr_block_context_is_instance
    c = ContextClass.new
    c.config_attr_context = nil
    assert_equal "Instance", c.config_attr_context 
  end
  
  #
  # parse test
  #
  
  class ParseClass
    include Configurable
    config(:one, 'one') {|v| v.upcase }
  end
  
  def test_parse_parses_configs_from_argv
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
    assert_configurations_equal({
      :one => [:one, :one=, 'one']
    }, IncludeBase.configurations)
    
    assert_configurations_equal({
      :one => [:one, :one=, 'one'], 
      :two => [:two, :two=, 'two']
    }, IncludeSubclass.configurations)
  end
  
  def test_subclasses_inherit_accessors
    t = IncludeSubclass.new
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
  end
  
  def test_inherited_configurations_can_be_overridden
    assert_configurations_equal({:one => [:one, :one=, 'one']}, IncludeBase.configurations)
    assert_configurations_equal({:one => [:one, :one=, 'ONE']}, OverrideSubclass.configurations)
  end
  
  #
  # lazydoc test
  #
  
  class LazydocNestClass
    include Configurable
  end
  
  class LazydocClass
    include Configurable
  
    config_attr :one, 'value'                               # one with documentation
    config_attr :two, 'value', :desc => "two description"   # two ignored documentation
    
    config :three, 'value'                                  # three with documentation
    config :four, 'value', :desc => "four description"      # four ignored documentation
    
    nest :five, LazydocNestClass                            # five with documentation
    nest :six, LazydocNestClass, :desc => "six description" # six ignored documentation
  end
  
  def test_configurable_registers_configs_with_lazydoc_unless_desc_is_specified
    [:one, :three, :five].each do |doc_config|
      desc = LazydocClass.configurations[doc_config].attributes[:desc]
      assert_equal "#{doc_config} with documentation", desc.to_s
    end
    
    [:two, :four, :six].each do |nodoc_config|
      desc = LazydocClass.configurations[nodoc_config].attributes[:desc]
      assert_equal "#{nodoc_config} description", desc.to_s
    end
  end
  
  module LazydocConfigModule
    include Configurable

    config_attr :one, 'value'                             # one with documentation
    config_attr :two, 'value', :desc => "two description" # two ignored documentation
  end
  
  class LazydocIncludeClass
    include LazydocConfigModule
    
    config :three, 'value'                                # three with documentation
    config :four, 'value', :desc => "four description"    # four ignored documentation
  end
  
  def test_configurable_registers_documentation_for_configs_in_modules
    [:one, :three].each do |doc_config|
      desc = LazydocIncludeClass.configurations[doc_config].attributes[:desc]
      assert_equal "#{doc_config} with documentation", desc.to_s
    end
    
    [:two, :four].each do |nodoc_config|
      desc = LazydocIncludeClass.configurations[nodoc_config].attributes[:desc]
      assert_equal "#{nodoc_config} description", desc.to_s
    end
  end
  
  class LazydocIncludeClassDocSubclass < LazydocIncludeClass
    config_attr :five, 'value'                            # five with documentation
    config_attr :six, 'value', :desc => "six description" #  ignored documentation
  end
  
  def test_configurable_registers_documentation_for_configs_in_subclasses
    [:one, :three, :five].each do |doc_config|
      desc = LazydocClass.configurations[doc_config].attributes[:desc]
      assert_equal "#{doc_config} with documentation", desc.to_s
    end
    
    [:two, :four, :six].each do |nodoc_config|
      desc = LazydocClass.configurations[nodoc_config].attributes[:desc]
      assert_equal "#{nodoc_config} description", desc.to_s
    end
  end
  
  #
  # DEFAULT_ATTRIBUTES test
  #
  
  class DefaultOptionsClassOne
    include Configurable
  end
  
  class DefaultOptionsClassTwo
    include Configurable
    DEFAULT_ATTRIBUTES = DEFAULT_ATTRIBUTES.dup
    DEFAULT_ATTRIBUTES[:key] = 'value'
  end
  
  def test_default_attributes_may_be_overridden
    assert_equal({}, DefaultOptionsClassOne::DEFAULT_ATTRIBUTES[:key])
    assert_equal('value', DefaultOptionsClassTwo::DEFAULT_ATTRIBUTES[:key])
  end
  
  #
  # initialize test
  #
  
  class InitializeClass
    include Configurable
    config :key, 'value'
  end
  
  def test_initialize_initializes_config_if_necessary
    i = InitializeClass.new
    assert_equal(Configurable::ConfigHash, i.config.class)
    assert_equal({:key => 'value'}, i.config)
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
    i = NoInitializeClass.new
    assert_equal(Hash, i.config.class)
    assert_equal({:key => 'alt'}, i.config)
  end
  
  #
  # initialize_config test
  #
  
  class Sample
    include Configurable
    
    def initialize(overrides={})
      initialize_config(overrides, true)
    end
    
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two'
  end
  
  def test_initialize_config_merges_class_defaults_with_overrides
    t = Sample.new(:two => 2)
    assert_equal({:one => 'ONE', :two => 2}, t.config)
  end
  
  #
  # initialize_copy test
  #
  
  def test_duplicates_have_an_independent_config
    t1 = Sample.new
    t2 = t1.dup
    
    assert t1.config.object_id != t2.config.object_id
    
    t1.two = 2
    t2.two = 'two'
    assert_equal 2, t1.two
    assert_equal 'two', t2.two
  end
  
  def test_dup_passes_along_current_config_values
    t1 = Sample.new
    t1.two = 2
    t1.config[:three] = 3
    assert_equal({:one => 'ONE', :two => 2, :three => 3}, t1.config)
    
    t2 = t1.dup
    assert_equal({:one => 'ONE', :two => 2, :three => 3}, t2.config)
  end
  
  #
  # open_io test
  #
  
  class IoSample
    include Configurable
    config :output, $stdout, &c.io_or_nil(:<<)

    def say_hello
      open_io(output, 'w') do |io|
        io << 'hello!'
        'result'
      end
    end
  end
  
  def test_open_io_yields_IO_to_block
    Tempfile.open('io_sample', Dir::tmpdir) do |io|
      s = IoSample.new
      s.output = io
      s.say_hello
      
      io.flush
      io.rewind
      assert_equal 'hello!', io.read
    end
  end
  
  def test_open_io_opens_filepath_and_passes_file_to_block
    # not a great test....
    s = IoSample.new
    
    was_in_block = false
    s.send(:open_io, 1) do |io|
      assert_equal $stdout.stat.dev, io.stat.dev
      assert $stdout.object_id != io.object_id
      was_in_block = true
    end

    assert was_in_block
  end
  
  def test_open_io_opens_integer_file_descriptors_and_yields_to_block
    temp = Tempfile.new('io_sample')
    temp.close
    
    assert_equal '', File.read(temp.path)
    
    s = IoSample.new
    s.output = temp.path
    s.say_hello

    assert_equal 'hello!', File.read(temp.path)
  end
  
  def test_open_io_makes_parent_directories_if_needed
    path = __FILE__.chomp('.rb') + "/test_open_io_makes_parent_directories_if_needed/file.txt"
    assert !File.exists?(File.dirname(path))
    
    begin
      s = IoSample.new
      s.output = path
      s.say_hello

      assert_equal 'hello!', File.read(path)
    ensure
      if File.exists?(path)
        FileUtils.rm(path)
        FileUtils.rmdir(File.dirname(path))
      end
    end
  end
  
  def test_open_io_passes_non_nil_objects_to_block
    array = []
    
    s = IoSample.new
    s.output = array
    s.say_hello
    
    assert_equal ['hello!'], array
  end
  
  def test_open_io_returns_block_result
    Tempfile.open('io_sample', Dir::tmpdir) do |io|
      s = IoSample.new
      s.output = io
      assert_equal 'result', s.say_hello
    end
    
    s = IoSample.new
    s.output = []
    assert_equal 'result', s.say_hello
  end
  
  
  def test_open_io_does_not_pass_nil_to_block
    s = IoSample.new
    s.output = nil 
    assert_equal nil, s.say_hello
  end
  
  #
  # to_yaml test
  #
  
  class SerializeTest
    include Configurable
    config :key, 'value'
    config :upcase, 'value' do |obj|
      obj.upcase
    end
    config :int, 1, &c.integer
  end
  
  def test_configurable_serializes_and_deserializes_cleanly_as_YAML
    s = SerializeTest.new
    s.reconfigure :store => 'value'
    
    assert_equal 'value', s.key
    assert_equal 'VALUE', s.upcase
    assert_equal 1, s.int
    assert_equal 'value', s.config[:store]
    assert_equal [:key, :upcase, :int], s.config.delegates.keys
    
    deserialized = YAML.load(YAML.dump(s))
    
    assert deserialized.object_id != s.object_id
    assert_equal 'value', deserialized.key
    assert_equal 'VALUE', deserialized.upcase
    assert_equal 1, deserialized.int
    assert_equal 'value', deserialized.config[:store]
    assert_equal [:key, :upcase, :int], deserialized.config.delegates.keys
  end
end
