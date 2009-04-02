require  File.join(File.dirname(__FILE__), '../tap_test_helper')
require 'configurable/validation'

class ValidationTest < Test::Unit::TestCase
  include Configurable::Validation
  
  #
  # documentation test
  #
  
  def test_documentation
    integer = Configurable::Validation.integer
    assert_equal(Proc, integer.class)
    assert_equal 1, integer.call(1)
    assert_equal 1, integer.call('1')
    assert_raises(ValidationError) { integer.call(nil) }
  end
  
  #
  # validate test
  #
  
  def test_validate
    assert_raises(ValidationError) { validate(nil, []) }
    
    assert_equal 1, validate(1, [Integer])
    assert_raises(ValidationError) { validate(nil, [Integer]) }
    
    assert_equal 1, validate(1, [Integer, nil])
    assert_equal 1, validate(1, [1, nil])
    assert_equal nil, validate(nil, [Integer, nil])
    
    assert_equal "str", validate("str", [/str/])
    assert_raises(ValidationError) { validate("str", [/non/]) }
  end
  
  def test_validate_validates_with_block_if_no_validations_match
    result = validate("str", [/non/]) {|obj| true }
    assert_equal "str", result
    
    assert_raises(ValidationError) do
      validate("str", [/non/]) {|obj| false }
    end
  end
  
  def test_all_inputs_are_valid_if_validations_is_nil
    assert_equal "str", validate("str", nil)
    assert_equal 1, validate(1, nil)
    assert_equal nil, validate(nil, nil)
  end
  
  def test_validate_raisess_error_for_non_array_or_nil_inputs
    e = assert_raises(ArgumentError) { validate("str", "str") }
    assert_equal "validations must be nil, or an array of valid inputs", e.message
    
    e = assert_raises(ArgumentError) { validate("str", 1) }
    assert_equal "validations must be nil, or an array of valid inputs", e.message
  end
  
  #
  # load_if_yaml test
  #
  
  def test_load_if_yaml_loads_input_as_yaml_and_returns_object_if_valid
    assert_equal 2, load_if_yaml("2", Integer, nil)
    assert_equal nil, load_if_yaml("~", Integer, nil)
  end
  
  def test_load_if_yaml_returns_input_if_loaded_object_causes_error
    assert_equal " : value", load_if_yaml(" : value", nil)
  end
  
  def test_load_if_yaml_returns_input_if_loaded_object_is_invald
    assert_equal "string", load_if_yaml("string", Integer, nil)
  end
  
  #
  # check test
  #
  
  def test_check_returns_validation_block
    m = check(Integer)
    assert_equal Proc, m.class
    assert_equal 1, m.call(1)
    e = assert_raises(ValidationError) { m.call(nil) }
    assert_equal "expected [Integer] but was: nil", e.message
  end
  
  #
  # yaml test
  #
  
  def test_yaml_doc
    b = yaml(Integer, nil)
    assert_equal Proc, b.class
    assert_equal 1, b.call(1)
    assert_equal 1, b.call("1")
    assert_equal nil, b.call(nil)
    assert_raises(ValidationError) { b.call("str") }
  end
  
  def test_yaml_block_loads_strings_as_yaml_and_checks_result
    m = yaml(Integer)
    assert_equal Proc, m.class
    assert_equal 1, m.call(1)
    assert_equal 1, m.call("1")
    assert_raises(ValidationError) { m.call(nil) }
    assert_raises(ValidationError) { m.call("str") }
  end
  
  def test_yaml_simply_returns_loaded_input_when_validations_are_not_specified
    m = yaml
    assert_equal nil, m.call(nil)
    assert_equal "str", m.call("str")
    assert_equal [1,2,3], m.call("[1, 2, 3]")
  end
  
  #
  # string test
  #
  
  def test_string_documentation
    assert_equal Proc, string.class
    assert_equal 'str', string.call('str') 
    assert_equal "\n", string.call('\n') 
    assert_equal "\n", string.call("\n") 
    assert_equal "%s", string.call("%s") 
    assert_raises(ValidationError) { string.call(nil) }
    assert_raises(ValidationError) { string.call(:sym) }
  end
  
  #
  # string_or_nil test
  #
  
  def test_string_or_nil_documentation
    assert_equal nil, string_or_nil.call("~") 
    assert_equal nil, string_or_nil.call(nil) 
  end

  #
  # symbol test
  #

  def test_symbol_documentation
    assert_equal Proc, symbol.class
    assert_equal :sym, symbol.call(:sym)
    assert_equal :sym, symbol.call(':sym')
    assert_raises(ValidationError) { symbol.call(nil) }
    assert_raises(ValidationError) { symbol.call('str') }
  end

  #
  # symbol_or_nil test
  #
  
  def test_symbol_or_nil_documentation
    assert_equal nil, symbol_or_nil.call("~") 
    assert_equal nil, symbol_or_nil.call(nil) 
  end

  #
  # boolean test
  #

  def test_boolean_documentation
    assert_equal Proc, boolean.class
    assert_equal true, boolean.call(true)
    assert_equal false, boolean.call(false)

    assert_equal true, boolean.call('true')
    assert_equal true, boolean.call('yes')
    assert_equal nil, boolean.call(nil) 
    assert_equal false,boolean.call('FALSE')

    assert_raises(ValidationError) { boolean.call(1) }
    assert_raises(ValidationError) { boolean.call("str") }
  end

  def test_boolean_block_converts_input_to_boolean_using_yaml_and_checks_result
    assert_equal Proc, boolean.class

    assert_equal true, boolean.call(true)
    assert_equal true, boolean.call('true')
    assert_equal true, boolean.call('TRUE')
    assert_equal true, boolean.call('yes')

    assert_equal nil, boolean.call(nil)
    assert_equal false, boolean.call(false)
    assert_equal false, boolean.call('false')
    assert_equal false, boolean.call('FALSE')
    assert_equal false, boolean.call('no')

    assert_raises(ValidationError) { boolean.call(10) }
    assert_raises(ValidationError) { boolean.call("str") }
  end

  #
  # array test
  #

  def test_array_documentation
    assert_equal Proc, array.class
    assert_equal [1,2,3], array.call([1,2,3])
    assert_equal [1,2,3], array.call('[1, 2, 3]')
    assert_raises(ValidationError) { array.call(nil) }
    assert_raises(ValidationError) { array.call('str') }
  end

  #
  # array_or_nil test
  #
  
  def test_array_or_nil_documentation
    assert_equal nil, array_or_nil.call("~") 
    assert_equal nil, array_or_nil.call(nil) 
  end

  #
  # list test
  #
  
  def test_list_documentation
    assert_equal Proc, list.class
    assert_equal [1,2,3], list.call([1,2,3])
    assert_equal [1,'str'], list.call(['1', 'str'])
    assert_raises(ValidationError) { list.call('str') }
    assert_raises(ValidationError) { list.call(nil) }
  end

  #
  # hash test
  #

  def test_hash_documentation
    assert_equal Proc, hash.class
    assert_equal({'key' => 'value'}, hash.call({'key' => 'value'}))
    assert_equal({'key' => 'value'}, hash.call('key: value'))
    assert_raises(ValidationError) { hash.call(nil) }
    assert_raises(ValidationError) { hash.call('str') }
  end

  #
  # hash_or_nil test
  #
  
  def test_hash_or_nil_documentation
    assert_equal nil, hash_or_nil.call("~") 
    assert_equal nil, hash_or_nil.call(nil) 
  end
  
  #
  # integer test
  #

  def test_integer_documentation  
    assert_equal Proc, integer.class
    assert_equal 1, integer.call(1)
    assert_equal 1, integer.call('1')
    assert_raises(ValidationError) { integer.call(1.1) }
    assert_raises(ValidationError) { integer.call(nil) }
    assert_raises(ValidationError) { integer.call('str') }
  end

  #
  # integer_or_nil test
  #
  
  def test_integer_or_nil_documentation
    assert_equal nil, integer_or_nil.call("~") 
    assert_equal nil, integer_or_nil.call(nil) 
  end
  
  #
  # float test
  #

  def test_float_documentation
    assert_equal Proc, float.class
    assert_equal 1.1, float.call(1.1)
    assert_equal 1.1, float.call('1.1')
    assert_equal 1e6, float.call('1.0e+6')
    assert_raises(ValidationError) { float.call(1) }
    assert_raises(ValidationError) { float.call(nil) }
    assert_raises(ValidationError) { float.call('str') }
  end
  
  #
  # float_or_nil test
  #
  
  def test_float_or_nil_documentation
    assert_equal nil, float_or_nil.call("~") 
    assert_equal nil, float_or_nil.call(nil) 
  end
  
  #
  # num test
  #

  def test_num_documentation
    assert_equal Proc, num.class
    assert_equal 1.1, num.call(1.1)
    assert_equal 1, num.call(1)
    assert_equal 1e6, num.call(1e6)
    assert_equal 1.1, num.call('1.1')
    assert_equal 1e6, num.call('1.0e+6')
    assert_raises(ValidationError) { num.call(nil) }
    assert_raises(ValidationError) { num.call('str') }
  end
  
  #
  # num_or_nil test
  #
  
  def test_num_or_nil_documentation
    assert_equal nil, num_or_nil.call("~") 
    assert_equal nil, num_or_nil.call(nil) 
  end
  
  #
  # regexp test
  #
  
  def test_regexp_documentation
    assert_equal Proc, regexp.class
    assert_equal(/regexp/, regexp.call(/regexp/))
    
    yaml_str = '!ruby/regexp /regexp/'
    assert_equal(/regexp/, regexp.call(yaml_str))
    
    assert_equal(/(?i)regexp/, regexp.call('(?i)regexp'))
  end
  
  def test_regexp_converts_strings_that_do_not_load_to_regexps_into_regexps
    assert_equal(/1/, regexp.call("1"))
    assert_equal(//, regexp.call(""))
    assert_equal(/false/, regexp.call("false"))
  end
  
  def test_regexp_does_not_fail_for_bad_yaml
    assert_equal(/: a/, regexp.call(": a"))
  end

  #
  # regexp_or_nil test
  #
  
  def test_regexp_or_nil_documentation
    assert_equal nil, regexp_or_nil.call("~") 
    assert_equal nil, regexp_or_nil.call(nil) 
  end
  
  def test_regexp_or_nil_with_regexp_documentation
    assert_equal Proc, regexp_or_nil.class
    assert_equal(/regexp/, regexp_or_nil.call(/regexp/))
    
    yaml_str = '!ruby/regexp /regexp/'
    assert_equal(/regexp/, regexp_or_nil.call(yaml_str))
    
    assert_equal(/(?i)regexp/, regexp_or_nil.call('(?i)regexp'))
  end
  
  #
  # range test
  #
  
  def test_range_documentation
    assert_equal Proc, range.class
    assert_equal 1..10, range.call(1..10)
    assert_equal 1..10, range.call('1..10')
    assert_equal 'a'..'z', range.call('a..z')
    assert_equal(-10...10, range.call('-10...10'))
    assert_raises(ValidationError) { range.call(nil) }
    assert_raises(ValidationError) { range.call('1.10') }
    assert_raises(ValidationError) { range.call('a....z') }
    
    yaml_str = "!ruby/range \nbegin: 1\nend: 10\nexcl: false\n"
    assert_equal 1..10, range.call(yaml_str)
  end
  
  def test_range
    assert_equal 1..10, range.call('1..10')
    assert_equal 1e-3..1000, range.call('0.001..1000')
  end
  
  #
  # range_or_nil test
  #
  
  def test_range_or_nil_documentation
    assert_equal nil, range_or_nil.call("~") 
    assert_equal nil, range_or_nil.call(nil) 
  end
  
  def test_range_or_nil_with_range_documentation
    assert_equal Proc, range_or_nil.class
    assert_equal 1..10, range_or_nil.call(1..10)
    assert_equal 1..10, range_or_nil.call('1..10')
    assert_equal 'a'..'z', range_or_nil.call('a..z')
    assert_equal(-10...10, range_or_nil.call('-10...10'))
    # assert_raises(ValidationError) { range.call(nil) }
    assert_raises(ValidationError) { range_or_nil.call('1.10') }
    assert_raises(ValidationError) { range_or_nil.call('a....z') }
    
    yaml_str = "!ruby/range \nbegin: 1\nend: 10\nexcl: false\n"
    assert_equal 1..10, range_or_nil.call(yaml_str)
  end
  #
  # time test
  #
  
  def test_time_documentation
    assert_equal Proc, time.class
    
    now = Time.now
    assert_equal now, time.call(now)
  
    assert_equal '2008/08/08 12:00:00', time.call('2008-08-08 20:00:00.00 +08:00').getutc.strftime('%Y/%m/%d %H:%M:%S')
    assert_equal '2008/08/08 00:00:00', time.call('2008-08-08').strftime('%Y/%m/%d %H:%M:%S')

    assert_raises(ValidationError) { time.call(1) }
    assert_raises(ValidationError) { time.call(nil) }
    
    assert_equal Time.now.strftime('%Y/%m/%d %H:%M:%S'), time.call('str').strftime('%Y/%m/%d %H:%M:%S')
  end

  #
  # time_or_nil test
  #
  
  def test_time_or_nil_documentation
    assert_equal nil, time_or_nil.call("~") 
    assert_equal nil, time_or_nil.call(nil) 
  end
  
  def test_time_or_nil_with_time_documentation
    assert_equal Proc, time_or_nil.class
    
    now = Time.now
    assert_equal now, time_or_nil.call(now)
  
    assert_equal '2008/08/08 12:00:00', time_or_nil.call('2008-08-08 20:00:00.00 +08:00').getutc.strftime('%Y/%m/%d %H:%M:%S')
    assert_equal '2008/08/08 00:00:00', time_or_nil.call('2008-08-08').strftime('%Y/%m/%d %H:%M:%S')

    assert_raises(ValidationError) { time_or_nil.call(1) }
    # assert_raises(ValidationError) { time_or_nil.call(nil) }
    
    assert_equal Time.now.strftime('%Y/%m/%d %H:%M:%S'), time_or_nil.call('str').strftime('%Y/%m/%d %H:%M:%S')
  end
  
  #
  # select test
  #
  
  def test_select_documentation
    s = select(1,2,3, &integer)
    assert_equal Proc, s.class
    assert_equal 1, s.call(1)
    assert_equal 3, s.call('3')
  
    assert_raises(ValidationError) { s.call(nil) }
    assert_raises(ValidationError) { s.call(0) }
    assert_raises(ValidationError) { s.call('4') }
  end
  
  def test_select_does_not_transform_inputs_unless_block_is_specified
    s = select(1,2,3)
    assert_equal 3, s.call(3)
    assert_raises(ValidationError) { s.call('3') }
  end
  
  #
  # list_select test
  #
  
  def test_list_select_documentation
    s = list_select(1,2,3, &integer)
    assert_equal Proc, s.class
    assert_equal [1], s.call([1])
    assert_equal [1, 3], s.call([1, '3'])
    assert_equal [], s.call([])
  
    assert_raises(ValidationError) { s.call(1) }
    assert_raises(ValidationError) { s.call([nil]) }
    assert_raises(ValidationError) { s.call([0]) }
    assert_raises(ValidationError) { s.call(['4']) }
  end
  
  #
  # io test
  #
  
  def test_io_documentation
    assert_equal Proc, io.class
    assert_equal $stdout, io.call($stdout)
    assert_equal '/path/to/file', io.call('/path/to/file')
  
    assert_raises(ValidationError) { io.call(nil) }
    assert_raises(ValidationError) { io.call(10)  }
    
    array_io = io(:<<)
    assert_equal $stdout, array_io.call($stdout)
    assert_equal [], array_io.call([])
    assert_raises(ValidationError) { array_io.call(nil) }
  end
  
  #
  # io_or_nil test
  #
  
  def test_io_or_nil_documentation
    assert_equal nil, io_or_nil.call(nil)
  end
  
  def test_io_or_nil_with_api
    assert_equal [], io_or_nil(:<<).call([])
    assert_equal nil, io_or_nil(:<<).call(nil)
  end
end