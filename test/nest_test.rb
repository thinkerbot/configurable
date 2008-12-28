require  File.join(File.dirname(__FILE__), 'tap_test_helper')
require 'configurable'

class NestTest < Test::Unit::TestCase
  DelegateHash = Configurable::DelegateHash

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
    
    assert_equal :key_config_reader, config.reader
    assert_equal :key_config_writer, config.writer
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
  # 
  # def test_modification_of_configs_adjusts_instance_configs_and_vice_versa
  #   p = NestParent.new
  #   assert_equal({:key => 'value'}, p.key.config.to_hash)
  #   
  #   p.config[:key][:key] = 'zero'
  #   assert_equal({:key => 'zero'}, p.key.config.to_hash)
  #   
  #   p.config[:key] = {:key => 'two'}
  #   assert_equal({:key => 'two'}, p.key.config.to_hash)
  #     
  #   p.key.key = "two"
  #   assert_equal({:key => 'two'}, p.config[:key])
  #   
  #   p.key.reconfigure(:key => 'one')
  #   assert_equal({:key => 'one'}, p.config[:key])
  #   
  #   p.key.config[:key] = 'zero'
  #   assert_equal({:key => 'zero'}, p.config[:key])
  # end
  # 
  # def test_nest_raisess_error_for_non_configurable_input
  #   e = assert_raises(ArgumentError) { NestParent.send(:nest, :a, :b) }
  #   assert_equal "not a Configurable class: b", e.message
  # end
  # 
  # class RecursiveA
  #   include Configurable
  # end
  # 
  # class RecursiveB
  #   include Configurable
  #   nest :a, RecursiveA
  # end
  # 
  # class RecursiveC
  #   include Configurable
  #   nest :b, RecursiveB
  # end
  # 
  # def test_nest_raisess_error_for_infinite_nest
  #   e = assert_raises(RuntimeError) { RecursiveA.send(:nest, :A, RecursiveA) }
  #   assert_equal "infinite nest detected", e.message
  #   
  #   e = assert_raises(RuntimeError) { RecursiveA.send(:nest, :C, RecursiveC) }
  #   assert_equal "infinite nest detected", e.message
  # end
end