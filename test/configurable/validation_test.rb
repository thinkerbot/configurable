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
  # string test
  #
  
  def test_string_documentation
    assert_equal Proc, string.class
    assert_equal 'str', string.call('str') 
    assert_raises(ValidationError) { string.call(nil) }
    assert_raises(ValidationError) { string.call(:sym) }
  end
  
  #
  # string_or_nil test
  #
  
  def test_string_or_nil_documentation
    assert_equal nil, string_or_nil.call("") 
    assert_equal nil, string_or_nil.call(nil) 
  end
  
  #
  # switch test
  #

  def test_switch_documentation
    assert_equal Proc, switch.class
    assert_equal true, switch.call(true)
    assert_equal false, switch.call(false)

    assert_equal true, switch.call('true')
    assert_equal false, switch.call('false')

    assert_raises(ValidationError) { switch.call(1) }
    assert_raises(ValidationError) { switch.call("str") }
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
    assert_equal nil, integer_or_nil.call("") 
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
    assert_equal nil, float_or_nil.call("") 
    assert_equal nil, float_or_nil.call(nil) 
  end
  
  #
  # list test
  #
  
  def test_list_documentation
    assert_equal Proc, list.class
    assert_equal [1,2,3], list.call([1,2,3])
    assert_raises(ValidationError) { list.call('str') }
    assert_raises(ValidationError) { list.call(nil) }
  end
  
  def test_list_accepts_block_for_validation
    block = list(&integer)
    assert_equal Proc, block.class
    assert_equal [1,2,3], block.call([1,"2",3])
    assert_raises(ValidationError) { block.call(['1', 'str']) }
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
end