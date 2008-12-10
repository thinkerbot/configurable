require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class ConfigurableTest < Test::Unit::TestCase
  Delegate = Configurable::Delegate
  DelegateHash = Configurable::DelegateHash
  Validation = Configurable::Validation
  
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
  # config declaration tests
  #

  class DeclarationClass
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
    t = DeclarationClass.new
    
    assert_nil t.one
    t.one = 'one'
    
    assert_equal 'ONE', t.one
    assert_equal 'ONE', t.instance_variable_get(:@one)
  end
  
  #
  # config_attr test
  #
  
  class ConfigAttrClass
    include Configurable
  
    config_attr :trues, 'value', :reader => true, :writer => true
    config_attr :falses, 'value', :reader => false, :writer => false
    config_attr :nils, 'value', :reader => nil, :writer => nil
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
  
  def test_config_attr_reader_and_writer_nil
    o = ConfigAttrClass.new
    assert !o.respond_to?(:nils)
    assert !o.respond_to?(:nils=)
    
    config = ConfigAttrClass.configurations[:nils]
    assert_equal nil, config.reader
    assert_equal nil, config.writer
  end
  
  def test_block_without_writer_true_raises_error
    e = assert_raise(ArgumentError) { ConfigAttrClass.send(:config_attr, :key, 'val', :writer => :alt) {} }
    assert_equal "a block may not be specified without writer == true", e.message
    
    e = assert_raise(ArgumentError) { ConfigAttrClass.send(:config_attr, :key, 'val', :writer => false) {} }
    assert_equal "a block may not be specified without writer == true", e.message
    
    e = assert_raise(ArgumentError) { ConfigAttrClass.send(:config_attr, :key, 'val', :writer => nil) {} }
    assert_equal "a block may not be specified without writer == true", e.message
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
  # indifferent access test
  #
  
  class IndifferentAccessClass
    include Configurable
    
    def initialize
      initialize_config
    end
    
    config(:one, 'one') {|v| v.upcase }
  end
  
  def test_access_is_indifferent_through_config
    s = IndifferentAccessClass.new
    
    s.config['one'] = 'value'
    assert_equal 'VALUE', s.one
    assert_equal 'VALUE', s.config['one']
    assert_equal 'VALUE', s.config[:one]
    
    s.config[:one] = 'alt'
    assert_equal 'ALT', s.one
    assert_equal 'ALT', s.config['one']
    assert_equal 'ALT', s.config[:one]
  end
  
  class NonIndifferentAccessClass
    include Configurable
    
    def initialize
      initialize_config
    end
    
    config(:one, 'one') {|v| v.upcase }
    use_indifferent_access(false)
  end
  
  def test_indifferent_access_may_be_turned_off
    s = NonIndifferentAccessClass.new
    
    s.config['one'] = 'value'
    assert_equal 'ONE', s.one
    assert_equal 'value', s.config['one']
    assert_equal 'ONE', s.config[:one]
    
    s.config[:one] = 'alt'
    assert_equal 'ALT', s.one
    assert_equal 'value', s.config['one']
    assert_equal 'ALT', s.config[:one]
  end
  
  class IndifferentSubClass < IndifferentAccessClass
  end
  
  class NonIndifferentSubClass < NonIndifferentAccessClass
  end
  
  def test_indifferent_access_is_inherited
    assert IndifferentSubClass.configurations.kind_of?(Configurable::IndifferentAccess)
    assert !NonIndifferentSubClass.configurations.kind_of?(Configurable::IndifferentAccess)
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
      assert_equal Configurable::Description, desc.class
      assert_equal "with documentation", desc.trailer
    end
    
    [:two, :four, :six].each do |nodoc_config|
      desc = LazydocClass.configurations[nodoc_config].attributes[:desc]
      assert_equal String, desc.class
      assert_equal "description", desc.to_s
    end
  end
  
  #
  # DEFAULT_OPTIONS test
  #
  
  class DefaultOptionsClassOne
    include Configurable
  end
  
  class DefaultOptionsClassTwo
    include Configurable
    DEFAULT_OPTIONS = DEFAULT_OPTIONS.dup
    DEFAULT_OPTIONS[:key] = 'value'
  end
  
  def test_default_attributes_may_be_overridden
    assert_equal({}, DefaultOptionsClassOne::DEFAULT_OPTIONS[:key])
    assert_equal('value', DefaultOptionsClassTwo::DEFAULT_OPTIONS[:key])
  end
  
  #
  # initialize_config test
  #
  
  class Sample
    include Configurable
    
    def initialize(overrides={})
      initialize_config(overrides)
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
