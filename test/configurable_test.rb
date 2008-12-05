require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class ConfigurableTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  Validation = Configurable::Validation
  
  # sample class repeatedly used in tests
  class Sample
    include Configurable
    
    def initialize
      initialize_config
    end
    
    config(:one, 'one') {|v| v.upcase }
    config :two, 'two'
  end
  
  def test_sample
    assert_equal({
      :one => Delegate.new('one', 'one=', 'one'), 
      :two => Delegate.new('two', 'two=', 'two')
    }, Sample.configurations)
    
    s = Sample.new
    s.one = 'one'
    assert_equal 'ONE', s.one
  end
  
  #
  # documentation test
  #
  
  class ConfigClass
    include Configurable
  
    config :one, 'one'
    config :two, 'two'
    config :three, 'three'
  
    def initialize(overrides={})
      initialize_config(overrides)
    end
  end
  
  class SubClass < ConfigClass
    config(:one, 'one') {|v| v.upcase }
    config :two, 2, &c.integer
  end
  
  class DocAlternativeClass
    include Configurable
  
    config_attr :sym, 'value', :reader => :get_sym, :writer => :set_sym
  
    def initialize
      initialize_config
    end
    
    def get_sym
      @sym
    end
  
    def set_sym(input)
      @sym = input.to_sym
    end
  end
  
  def test_documentation
    c = ConfigClass.new
    assert_equal(DelegateHash, c.config.class)
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
    e = assert_raise(Validation::ValidationError) { s.two = nil }
    assert_equal "expected [Integer] but was: nil", e.message
    
    e = assert_raise(Validation::ValidationError) { s.two = 'str' }
    assert_equal "expected [Integer] but was: \"str\"", e.message
    
    alt = DocAlternativeClass.new
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
   
  def test_extend_initializes_class_configurations
    assert_equal({}, IncludeClass.configurations)
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
  
  #
  # config declaration tests
  #

  class SampleClass
    include Configurable
    
    def initialize
      @zero = @one = @two = @three = nil
    end
    
    config_attr :zero, 'zero' do |value|
      @zero = value.upcase
      nil
    end
    
    config :one, 'one' do |value|
      value.upcase
    end
    
    config :two, 'two'
    
    config :three
  end
  
  def test_config_adds_configurations_to_class_configuration
    assert_equal({
      :zero =>  Delegate.new('zero', 'zero=', 'zero'),
      :one =>   Delegate.new('one', 'one=', 'one'),
      :two =>   Delegate.new('two', 'two=', 'two'),
      :three => Delegate.new('three', 'three=', nil)
    },
    SampleClass.configurations)
  end
  
  def test_config_generates_accessors
    t = SampleClass.new
    [:zero, :one, :two, :three].each do |config|
      assert t.respond_to?(config)
      assert t.respond_to?("#{config}=")
    end
  end
  
  def test_config_reader_reads_instance_variable
    t = SampleClass.new
    assert_nil t.three
    t.instance_variable_set(:@three, 'three')
    assert_equal 'three', t.three
  end
  
  def test_config_writer_writes_instance_variable
    t = SampleClass.new
    assert_nil t.instance_variable_get(:@three)
    t.three = 'three'
    assert_equal 'three', t.instance_variable_get(:@three)
  end
  
  def test_config_with_block_uses_block_return_to_set_instance_variable
    t = SampleClass.new
    
    assert_nil t.one
    t.one = 'one'
    
    assert_equal 'ONE', t.one
    assert_equal 'ONE', t.instance_variable_get(:@one)
  end
  
  #
  # config_attr test
  #
  
  class OptionClass
    include Configurable
  
    config_attr :trues, 'value', :reader => true, :writer => true
    config_attr :falses, 'value', :reader => false, :writer => false
    config_attr :nils, 'value', :reader => nil, :writer => nil
  end
  
  def test_config_attr_reader_and_writer_true
    o = OptionClass.new
    assert o.respond_to?(:trues)
    assert o.respond_to?(:trues=)
    
    config = OptionClass.configurations[:trues]
    assert_equal :trues, config.reader
    assert_equal :trues=, config.writer
  end
  
  def test_config_attr_reader_and_writer_false
    o = OptionClass.new
    assert !o.respond_to?(:falses)
    assert !o.respond_to?(:falses=)
    
    config = OptionClass.configurations[:falses]
    assert_equal :falses, config.reader
    assert_equal :falses=, config.writer
  end
  
  def test_config_attr_reader_and_writer_nil
    o = OptionClass.new
    assert !o.respond_to?(:nils)
    assert !o.respond_to?(:nils=)
    
    config = OptionClass.configurations[:nils]
    assert_equal nil, config.reader
    assert_equal nil, config.writer
  end
  
  def test_block_without_writer_true_raises_error
    e = assert_raise(ArgumentError) { OptionClass.send(:config_attr, :key, 'val', :writer => :alt) {} }
    assert_equal "a block may not be specified without writer == true", e.message
    
    e = assert_raise(ArgumentError) { OptionClass.send(:config_attr, :key, 'val', :writer => false) {} }
    assert_equal "a block may not be specified without writer == true", e.message
    
    e = assert_raise(ArgumentError) { OptionClass.send(:config_attr, :key, 'val', :writer => nil) {} }
    assert_equal "a block may not be specified without writer == true", e.message
  end
  
  #
  # config context test
  #
  
  class ContextCheck
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
    c = ContextCheck.new
    c.config_context = nil
    assert_equal "Class", c.config_context
  end
  
  def test_config_attr_block_context_is_instance
    c = ContextCheck.new
    c.config_attr_context = nil
    assert_equal "Instance", c.config_attr_context 
  end
  
  #
  # nest test
  #
  
  class A
    include Configurable
    config :key, 'value'

    def initialize(overrides={})
      initialize_config(overrides)
    end
  end

  class B
    include Configurable
    nest :a, A

    def initialize(overrides={})
      initialize_config(overrides)
    end
  end
  
  class C
    include Configurable
    nest(:a, A) {|overrides| A.new(overrides) }

    def initialize(overrides={})
      initialize_config(overrides)
    end
  end
  
  def test_nest_documentation
    b = B.new
    assert_equal({:key => 'value'}, b.config[:a])
  
    c = C.new
    assert_equal("value", c.a.key)
    
    c.a.key = "one"
    assert_equal({:key => 'one'}, c.config[:a].to_hash)

    c.config[:a][:key] = 'two'
    assert_equal("two", c.a.key)
  
    c.config[:a] = {:key => 'three'}
    assert_equal("three", c.a.key)
  end
  
  class NestChild
    include Configurable    
    def initialize(overrides={})
      initialize_config(overrides)
    end
    
    config :key, 'value'
  end
  
  class NestParent
    include Configurable
    def initialize(overrides={})
      initialize_config(overrides)
    end
    
    nest :key, NestChild do |overrides|
      NestChild.new(overrides)
    end
    
    nest :blockless, NestChild
  end
  
  def test_nest_creates_reader_initialized_to_subclass
    p = NestParent.new
    assert p.respond_to?(:key)
    assert_equal NestChild,  p.key.class
  end
  
  def test_nest_without_block_does_not_define_accessors
    p = NestParent.new
    assert !p.respond_to?(:blockless)
  end
  
  def test_define_adds_configs_by_key_to_configurations
    assert NestParent.configurations.key?(:key)
    config = NestParent.configurations[:key]
    
    assert_equal :key_config, config.reader
    assert_equal :key_config=, config.writer
    assert_equal DelegateHash, config.default.class
    assert_equal NestChild.configurations, config.default.delegates
    
    assert NestParent.configurations.key?(:blockless)
    config = NestParent.configurations[:blockless]
    assert_equal nil, config.reader
    assert_equal nil, config.writer
    assert_equal DelegateHash, config.default.class
    assert_equal NestChild.configurations, config.default.delegates
  end
  
  def test_instance_is_initialized_with_defaults
    p = NestParent.new 
    assert_equal({:key => {:key => 'value'}, :blockless => {:key => 'value'}}, p.config.to_hash)
    assert_equal({:key => 'value'}, p.key.config.to_hash)
  end
  
  def test_instance_is_initialized_with_overrides
    p = NestParent.new :key => {:key => 'one'}
    assert_equal({:key => {:key => 'one'}, :blockless => {:key => 'value'}}, p.config.to_hash)
    assert_equal({:key => 'one'}, p.key.config.to_hash)
  end
  
  def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
    p = NestParent.new
    assert_equal({:key => 'value'}, p.key.config.to_hash)
    
    p.config[:key][:key] = 'zero'
    assert_equal({:key => 'zero'}, p.key.config.to_hash)
    
    p.config[:key] = {:key => 'two'}
    assert_equal({:key => 'two'}, p.key.config.to_hash)
      
    p.key.key = "two"
    assert_equal({:key => 'two'}, p.config[:key])
    
    p.key.reconfigure(:key => 'one')
    assert_equal({:key => 'one'}, p.config[:key])
    
    p.key.config[:key] = 'zero'
    assert_equal({:key => 'zero'}, p.config[:key])
  end
  
  def test_nest_raises_error_for_non_configurable_input
    e = assert_raise(ArgumentError) { NestParent.send(:nest, :a, :b) }
    assert_equal "not a Configurable class: b", e.message
  end
  
  class RecursiveA
    include Configurable
  end
  
  class RecursiveB
    include Configurable
    nest :a, RecursiveA
  end
  
  class RecursiveC
    include Configurable
    nest :b, RecursiveB
  end
  
  def test_nest_raises_error_for_infinite_nest
    e = assert_raise(RuntimeError) { RecursiveA.send(:nest, :A, RecursiveA) }
    assert_equal "infinite nest detected", e.message
    
    e = assert_raise(RuntimeError) { RecursiveA.send(:nest, :C, RecursiveC) }
    assert_equal "infinite nest detected", e.message
  end
  
  #
  # lazydoc test
  #
  
  class LazydocNestClass
    include Configurable
  end
  
  class LazydocClass
    include Configurable
  
    config_attr :one, 'value'                           # with documentation
    config_attr :two, 'value', :desc => "description"   # ignored documentation
    
    config :three, 'value'                              # with documentation
    config :four, 'value', :desc => "description"       # ignored documentation
    
    nest :five, LazydocNestClass                        # with documentation
    nest :six, LazydocNestClass, :desc => "description" # ignored documentation
  end
  
  def test_configurable_registers_configs_with_lazydoc_unless_desc_is_specified
    LazydocClass.lazydoc.resolve
    
    [:one, :three, :five].each do |doc_config|
      desc = LazydocClass.configurations[doc_config].attributes[:desc]
      assert_equal Lazydoc::Comment, desc.class
      assert_equal "with documentation", desc.trailer
    end
    
    [:two, :four, :six].each do |nodoc_config|
      desc = LazydocClass.configurations[nodoc_config].attributes[:desc]
      assert_equal String, desc.class
      assert_equal "description", desc.to_s
    end
  end
  
  #
  # indifferent access test
  #
  
  def test_access_is_indifferent_through_config
    s = Sample.new
    
    s.config['one'] = 'value'
    assert_equal 'VALUE', s.one
    assert_equal 'VALUE', s.config['one']
    assert_equal 'VALUE', s.config[:one]
    
    s.config[:one] = 'alt'
    assert_equal 'ALT', s.one
    assert_equal 'ALT', s.config['one']
    assert_equal 'ALT', s.config[:one]
  end
  
  #
  # initialize_config test
  #
  
  def test_initialize_config_merges_class_defaults_with_overrides
    t = Sample.new
    t.send(:initialize_config, {:two => 2})
    assert_equal({:one => 'ONE', :two => 2}, t.config)
  end
  
  #
  # initialize_copy test
  #
  
  def test_dup_reinitializes_config
    t1 = Sample.new
    t2 = t1.dup
    
    assert_not_equal t1.config.object_id, t2.config.object_id
    
    t1.two = 2
    t2.two = 'two'
    assert_equal 2, t1.two
    assert_equal 'two', t2.two
  end
  
end
