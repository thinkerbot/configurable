require File.expand_path('../../test_helper', __FILE__)
require 'configurable'
require 'time'

class ConfigTypesTest < Test::Unit::TestCase
  
  NOW = Time.now
  class TimeExample
    include Configurable
  
    config_type(:time, Time) do |input|
      Time.parse(input)
    end.uncast do |time|
      time.strftime('%Y-%m-%d %H:%M:%S')
    end
  
    config :obj, NOW
  end
  
  def test_time_example
    c = TimeExample.new
    assert_equal NOW, c.obj

    c.config.import('obj' => 'Sun Dec 05 16:52:19 -0700 2010')
    assert_equal '2010-12-05', c.obj.strftime('%Y-%m-%d')

    expected = {'obj' => '2010-12-05 16:52:19'}
    assert_equal expected, c.config.export
  end
  
  class RangeExample
    include Configurable
  
    config_type(:range, Range) do |input|
      Range.new(
        input['begin'], 
        input['end'],
        input['exclusive']
      )
    end.uncast do |value|
      { 
        'begin'     => value.begin,
        'end'       => value.end,
        'exclusive' => value.exclude_end?
      }
    end
  
    config :obj, 1..10
  end
  
  def test_range_example
    c = RangeExample.new
    assert_equal 1..10, c.obj
  
    c.config.import('obj' => {'begin' => 2, 'end' => 20, 'exclusive' => false})
    assert_equal 2..20, c.obj
  
    c.obj = 3...30
    expected = {'obj' => {'begin' => 3, 'end' => 30, 'exclusive' => true}}
    assert_equal expected, c.config.export
    
    config = RangeExample.configs[:obj]
    assert_equal RangeExample::RangeType, config.type.class
  end
  
  class A
    include Configurable
    config_type :datetime, Date, Time, DateTime
    config :a, Time.now     # matches :datetime type
  end

  class B < A
    config_type :time, Time

    config :b, Time.now     # matches :time type
    config :c, Date.today   # skips :time, walks up to match :datetime
  end

  class C < B
    config_type :date1, Date
    config_type :date2, Date

    config :d, Date.today, :type => :date1
    config :e, Date.today, :type => :date2
  end
  
  def test_matching
    configs = C.configs
    assert_equal A::DatetimeType, configs[:a].type.class
    assert_equal B::TimeType,     configs[:b].type.class
    assert_equal A::DatetimeType, configs[:c].type.class
    assert_equal C::Date1Type,    configs[:d].type.class
    assert_equal C::Date2Type,    configs[:e].type.class
  end
  
  class Parent
    include Configurable
    config_type :datetime, Time, Date

    config :a, {:b => Time.now}
    config :c do
      config_type :time, Time

      config :d, Time.now
      config :e, Date.today
    end
    config :f, Date.today
  end

  def test_matching_in_nest_classes
    configs = Parent.configs
    assert_equal Configurable::ConfigTypes::NestType, configs[:a].type.class
    assert_equal Configurable::ConfigTypes::NestType, configs[:c].type.class
    assert_equal Parent::DatetimeType,                configs[:f].type.class
    
    a_configs = configs[:a].type.configurable.class.configs
    assert_equal Parent::DatetimeType, a_configs[:b].type.class
    
    c_configs = configs[:c].type.configurable.class.configs
    assert_equal Parent::C::TimeType,  c_configs[:d].type.class
    assert_equal Parent::DatetimeType, c_configs[:e].type.class
  end
end