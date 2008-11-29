require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class ConfigurableTest < Test::Unit::TestCase
  acts_as_subset_test
  
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
      :one => Configuration.new('one', 'one=', 'one'), 
      :two => Configuration.new('two', 'two=', 'two')
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
  
  def test_documentation
    c = ConfigClass.new
    assert_equal(ConfigurationHash, c.config.class)
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
  end
  
  #
  # include test
  #
  
  class IncludeClass
    include Configurable
  end
  
  def test_include_extends_class_with_ConfigurableClass
    assert IncludeClass.kind_of?(ConfigurableClass)
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
    assert_equal({:one => Configuration.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({
      :one => Configuration.new(:one, :one=, 'one'), 
      :two => Configuration.new(:two, :two=, 'two')
    }, IncludeSubclass.configurations)
  end
  
  def test_subclasses_inherit_accessors
    t = IncludeSubclass.new
    assert t.respond_to?(:one)
    assert t.respond_to?("one=")
  end
  
  def test_inherited_configurations_can_be_overridden
    assert_equal({:one => Configuration.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({:one => Configuration.new(:one, :one=, 'ONE')}, OverrideSubclass.configurations)
  end
  
  def test_manual_changes_to_inherited_configurations_do_not_propogate_to_superclass
    ChangeDefaultSubclass.configurations[:one].default = 'two'
    
    assert_equal({:one => Configuration.new(:one, :one=, 'one')}, IncludeBase.configurations)
    assert_equal({:one => Configuration.new(:one, :one=, 'two')}, ChangeDefaultSubclass.configurations)
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
      :zero =>  Configuration.new('zero', 'zero=', 'zero'),
      :one =>   Configuration.new('one', 'one=', 'one'),
      :two =>   Configuration.new('two', 'two=', 'two'),
      :three => Configuration.new('three', 'three=', nil)
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
  
  class DocSampleClass
    include Configurable
  
    def initialize
      initialize_config
    end
    
    config_attr :str, 'value'
    config_attr(:upcase, 'value') {|input| @upcase = input.upcase } 
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
  
  def test_config_attr_documentation
    s = DocSampleClass.new
    assert_equal ConfigurationHash, s.config.class
    assert_equal 'value', s.str
    assert_equal 'value', s.config[:str]
  
    s.str = 'one'
    assert_equal 'one', s.config[:str]
    
    s.config[:str] = 'two' 
    assert_equal 'two', s.str
    
    ###
    alt = DocAlternativeClass.new
    assert_equal false, alt.respond_to?(:sym)
    assert_equal false, alt.respond_to?(:sym=)
    
    alt.config[:sym] = 'one'
    assert_equal :one, alt.get_sym
  
    alt.set_sym('two')
    assert_equal :two, alt.config[:sym]
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
  
  #
  # benchmarks
  #
  
  class ConfigBenchmark
    include Configurable
    
    config :key, nil
    config(:block, nil) {|value| value }
    attr_accessor :attr
  end

  def test_config_and_attr_speed
    t = ConfigBenchmark.new 
    t.send(:initialize_config)
    
    benchmark_test(20) do |x|
      n = 100000
      
      puts "writers"
      x.report("100k key= ") { n.times { t.key = 1 } }
      x.report("100k block= ") { n.times { t.block = 1 } }
      x.report("100k attr= ") { n.times { t.attr = 1 } }
      x.report("100k config[key]= ") { n.times { t.config[:key] = 1 } }
      x.report("100k config[block]= ") { n.times { t.config[:block] = 1 } }
      x.report("100k config[attr]= ") { n.times { t.config[:attr] = 1 } }
      
      puts "readers"
      x.report("100k key") { n.times { t.key } }
      x.report("100k block") { n.times { t.block } }
      x.report("100k attr") { n.times { t.attr } }
      x.report("100k config[key]") { n.times { t.config[:key] } }
      x.report("100k config[block]") { n.times { t.config[:block] } }
      x.report("100k config[attr]") { n.times { t.config[:attr] } }
      
    end
  end
end
