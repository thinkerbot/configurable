require File.expand_path('../../../test_helper', __FILE__) 
require 'configurable/config_types'
require 'ostruct'

class NestTypeTest < Test::Unit::TestCase
  include Configurable::ConfigTypes
  
  class MockConfigs
    def import(input)
      :import
    end
    
    def export(value)
      :export
    end
  end
  
  attr_reader :type
  
  def setup
    configurable_class = OpenStruct.new(:configs => MockConfigs.new)
    @type = NestType.new :configurable_class => configurable_class
  end
  
  #
  # initialize test
  #
  
  def test_initialize_raises_error_for_invalid_configurable_class
    err = assert_raises(ArgumentError) { NestType.new }
    assert_equal "not a configurable class: nil", err.message
  end
  
  #
  # cast test
  #
  
  def test_cast_delegates_to_import_on_configurable_class_configs
    assert_equal :import, type.cast(:obj)
  end
  
  #
  # uncast test
  #
  
  def test_uncast_delegates_to_export_on_configurable_class_configs
    assert_equal :export, type.uncast(:obj)
  end
end