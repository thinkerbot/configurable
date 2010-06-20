require File.expand_path('../../test_helper.rb', __FILE__) 
require 'configurable/nest_config'

class NestConfigTest < Test::Unit::TestCase
  Config = Configurable::Config
  NestConfig = Configurable::NestConfig
  
  # re-implements the portions of Configurable that
  # get used by NestConfig.  Configurable must be
  # included because NestConfig checks for it.
  class NestClass
    include Configurable
    
    class << self
      attr_accessor :configurations
    end
    
    attr_reader :config
    
    def initialize(config={})
      @config = config
    end
    
    def reconfigure(overrides)
      @config.merge!(overrides)
    end
  end
  
  class Receiver
    attr_accessor :key
  end
  
  attr_reader :c, :receiver
  
  def setup
    @c = NestConfig.new(NestClass, :key, :key=)
    @receiver = Receiver.new
  end
  
  #
  # initialize test
  #
  
  def test_initialize
    c = NestConfig.new(NestClass, 'key', 'key=', {:attr => 'value'}, false)
    assert_equal NestClass, c.nest_class
    assert_equal :key, c.reader
    assert_equal :key=, c.writer
    assert_equal false, c.init?
    assert_equal({:attr => 'value'}, c.attributes)
  end
  
  def test_nest_config_must_be_set_to_a_configurable_class
    obj = Object.new
    e = assert_raises(ArgumentError) { NestConfig.new(obj, nil) }
    assert_equal "not a Configurable class: #{obj.inspect}", e.message
    
    e = assert_raises(ArgumentError) { NestConfig.new(Object, nil) }
    assert_equal "not a Configurable class: #{Object.inspect}", e.message
  end
  
  def test_reader_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { NestConfig.new(NestClass, nil) }
    assert_equal "reader may not be nil", e.message
  end
  
  def test_writer_may_not_be_set_to_nil
    e = assert_raises(ArgumentError) { NestConfig.new(NestClass, 'key', nil) }
    assert_equal "writer may not be nil", e.message
  end
  
  #
  # default test
  #
  
  def test_default_returns_hash_of_defaults_for_nest_class
    NestClass.configurations = {
      :a => Config.new(:reader, :writer, 'a'),
      :b => Config.new(:reader, :writer, 'b')
    }
    
    assert_equal({:a => 'a', :b => 'b'}, c.default)
  end
  
  class AnotherNestClass < NestClass
  end
  
  def test_default_recursively_picks_up_nest_delegate_defaults
    NestClass.configurations = {
      :a => Config.new(:reader, :writer, 'a'),
      :b => NestConfig.new(AnotherNestClass, :reader, :writer)
    }
    
    AnotherNestClass.configurations = {
      :c => Config.new(:reader, :writer, 'c'),
    }
    
    assert_equal({:a => 'a', :b => {:c => 'c'}}, c.default)
  end
  
  #
  # get test
  #
  
  def test_get_returns_the_config_for_the_instance_returned_by_reader_on_receiver
    config = {}
    receiver.key = NestClass.new(config)
    
    assert_equal config.object_id, c.get(receiver).object_id
  end
  
  def test_get_returns_nil_if_reader_returns_nil_on_receiver
    assert_equal nil, receiver.key
    assert_equal nil, c.get(receiver)
  end
  
  #
  # set test
  #
  
  def test_set_reconfigures_the_instance_returned_by_reader_on_receiver
    config = {:a => 'a', :b => 'b'}
    receiver.key  = NestClass.new(config)
    
    c.set(receiver, {:b => 'B', :c => 'C'})
    assert_equal({:a => 'a', :b => 'B', :c => 'C'}, config)
  end
  
  def test_set_initializes_instance_on_receiver_if_necessary
    assert_equal nil, receiver.key
    c.set(receiver, {:a => 'a', :b => 'b'})
    
    assert_equal NestClass, receiver.key.class
    assert_equal({:a => 'a', :b => 'b'}, receiver.key.config)
  end
  
  def test_set_sets_instance_on_receiver_if_an_instance_of_nest_class
    instance = NestClass.new
    c.set(receiver, instance)
    assert_equal instance, receiver.key
  end
  
  #
  # init test
  #
  
  def test_init_creates_new_instance_of_nest_class_and_sets_on_receiver 
    assert_equal nil, receiver.key
    c.init(receiver) 
    assert_equal NestClass, receiver.key.class
  end
end