require File.expand_path('../../test_helper', __FILE__)
require 'configurable'

class ConfigSyntaxTest < Test::Unit::TestCase
  class ConfigClass
    include Configurable
    config :str, 'one'
  end
  
  def test_basic_syntax
    c = ConfigClass.new
    assert_equal 'one', c.str
    c.str = 'two'
    assert_equal 'two', c.config[:str]
    c.config[:str] = 'three'
    assert_equal 'three', c.str
    assert_equal({:str => 'three'}, c.config.to_hash)
  end

  class InitClass
    include Configurable
    config :str, 'one'

    def initialize(configs={})
      initialize_config(configs)
    end
  end
  
  def test_init
    c = InitClass.new(:str => 'two')
    assert_equal 'two', c.str
  end

  class KeyNameClass
    include Configurable
    config :key, 'val', :name => 'name'
  end

  def test_key_name
    c = KeyNameClass.new
    assert_equal 'val', c.name
    assert_equal 'val', c.config[:key]
  end

  class ReaderWriterClass
    include Configurable
    config :str, 'one', :reader => :get, :writer => :set

    def get
      @ivar
    end

    def set(value)
      @ivar = value
    end
  end

  def test_reader_writer
    c = ReaderWriterClass.new
    assert_equal 'one', c.get
    c.set 'two'
    assert_equal 'two', c.config[:str]
    c.config[:str] = 'three'
    assert_equal 'three', c.get
    assert_equal({:str => 'three'}, c.config.to_hash)
  end
  
  def test_import_export
    configs = KeyNameClass.configs
    defaults = configs.to_default
    assert_equal({:key => 'val'}, defaults)

    static_data = configs.export(defaults)
    assert_equal({'name' => 'val'}, static_data)

    active_hash = configs.import({'name' => 'VAL'})
    assert_equal({:key => 'VAL'}, active_hash)

    c = KeyNameClass.new
    assert_equal({:key => 'val'}, c.config.to_hash)
    assert_equal({'name' => 'val'}, c.config.export)

    c.config.import({'name' => 'VAL'})
    assert_equal({:key => 'VAL'}, c.config.to_hash)
  end
  
  class ListClass
    include Configurable
    config :integers, [1, 2, 3]
  end

  def test_list_class
    c = ListClass.new
    assert_equal [1, 2, 3], c.integers
    c.config.import('integers' => ['7', '8'])
    assert_equal [7, 8], c.config[:integers]
  end
  
  class Parent
    include Configurable

    config :a, {:key => 'hash'}

    config :b do
      config :key, 'block'
    end

    class Child
      include Configurable
      config :key, 'instance'
    end
    config :c, Child.new
  end
  
  def test_nesting
    c = Parent.new
    
    expected = {
     :a => {:key => 'hash'},
     :b => {:key => 'block'},
     :c => {:key => 'instance'}
    }
    assert_equal expected, c.config.to_hash
    
    assert_equal 'hash', c.a.key
    assert_equal 'hash', c.config[:a][:key]
    c.config[:a][:key] = 'HASH'
    assert_equal 'HASH', c.a.key
    assert_equal({:key => 'HASH'}, c.a.config.to_hash)

    c.a = Parent::A.new
    assert_equal({:key => 'hash'}, c.config[:a])
    c.config[:a] = {:key => 'HASH'}
    assert_equal({:key => 'HASH'}, c.a.config.to_hash)
    
    c.config.import('b' => {'key' => 'BLOCK'})
    
    expected = {
     'a' => {'key' => 'HASH'},
     'b' => {'key' => 'BLOCK'},
     'c' => {'key' => 'instance'}
    }
    assert_equal expected, c.config.export
  end
  
  class A
    include Configurable
    config :a, 'one'
  end

  module B
    include Configurable
    config :b, 'two'
  end

  class C < A
    include B
    config :c, 'three'
  end

  class D < C
    config :a, 'ONE'
    undef_config :c
  end
  
  def test_inheritance
    c = C.new
    assert_equal 'one'  , c.a
    assert_equal 'two'  , c.b
    assert_equal 'three', c.c
    assert_equal({:a => 'one', :b => 'two', :c => 'three'}, c.config.to_hash)
    
    d = D.new
    assert_equal false, d.respond_to?(:c)
    assert_equal({:a => 'ONE', :b => 'two'}, d.config.to_hash)
  end
end