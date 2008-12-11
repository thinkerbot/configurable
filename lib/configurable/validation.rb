autoload(:YAML, 'yaml')

module Configurable
  # A hash of (block, default attributes) for config blocks.  The 
  # attributes for nil will be merged with those for the block.
  DEFAULT_ATTRIBUTES = Hash.new({})
  DEFAULT_ATTRIBUTES[nil] = {:reader => true, :writer => true}
  
  # Validation generates blocks for common validations and transformations of 
  # configurations set through Configurable.  In general these blocks load
  # string inputs as YAML and valdiate the results; non-string inputs are
  # simply validated.
  #
  #   integer = Validation.integer
  #   integer.class             # => Proc
  #   integer.call(1)           # => 1
  #   integer.call('1')         # => 1
  #   integer.call(nil)         # => ValidationError
  #
  #--
  # Developers: note the unusual syntax for declaring constants that are
  # blocks defined by lambda... ex:
  #
  #   block = lambda {}
  #   CONST = block
  #
  # This syntax plays well with RDoc, which otherwise gets jacked when you
  # do it all in one step.
  module Validation

    # Raised when a Validation block fails.
    class ValidationError < ArgumentError
      def initialize(input, validations)
        super case 
        when validations.empty?
          "no validations specified"
        else
          "expected #{validations.inspect} but was: #{input.inspect}"
        end
      end
    end

    # Raised when Validation#yamlize fails.
    class YamlizationError < ArgumentError
      def initialize(input, error)
        super "#{error} ('#{input}')"
      end
    end

    module_function

    # Registers the default attributes with the specified block
    # in Configurable::DEFAULT_ATTRIBUTES.
    def register(block, attributes)
      DEFAULT_ATTRIBUTES[block] = attributes
    end
    
    # Returns input if it matches any of the validations as in would in a case
    # statement.  Raises a ValidationError otherwise.  For example:
    #
    #   validate(10, [Integer, nil])
    #
    # Does the same as:
    #
    #   case 10
    #   when Integer, nil then input
    #   else raise ValidationError.new(...)
    #   end
    #
    # Note the validations input must be an Array or nil; validate will raise
    # an ArgumentError otherwise.  All inputs are considered VALID if 
    # validations == nil.
    def validate(input, validations)
      case validations
      when Array
  
        case input
        when *validations then input
        else raise ValidationError.new(input, validations)
        end
    
      when nil then input
      else raise ArgumentError, "validations must be nil, or an array of valid inputs"
      end
    end

    # Attempts to load the input as YAML.  Raises a YamlizationError
    # for errors.
    def yamlize(input)
      begin
        YAML.load(input)
      rescue
        raise YamlizationError.new(input, $!.message)
      end
    end

    # Returns a block that calls validate using the block input
    # and validations.
    def check(*validations)
      lambda {|input| validate(input, validations) }
    end

    # Returns a block that loads input strings as YAML, then
    # calls validate with the result and validations. Non-string 
    # inputs are validated directly.
    #
    #   b = yaml(Integer, nil)
    #   b.class                 # => Proc
    #   b.call(1)               # => 1
    #   b.call("1")             # => 1
    #   b.call(nil)             # => nil
    #   b.call("str")           # => ValidationError
    #
    # If no validations are specified, the result will be 
    # returned without validation.
    def yaml(*validations)
      if validations.empty?
        lambda do |input|
          input = yamlize(input) if input.kind_of?(String)
          input
        end
      else
        lambda do |input|
          input = yamlize(input) if input.kind_of?(String)
          validate(input, validations)
        end
      end
    end

    # Returns a block that checks the input is a string.
    # Moreover, strings are re-evaluated as string 
    # literals using %Q. 
    #
    #   string.class              # => Proc
    #   string.call('str')        # => 'str'
    #   string.call('\n')         # => "\n"
    #   string.call("\n")         # => "\n"
    #   string.call("%s")         # => "%s"
    #   string.call(nil)          # => ValidationError
    #   string.call(:sym)         # => ValidationError
    #
    def string(); STRING; end
    string_validation_block = lambda do |input|
      input = validate(input, [String])
      eval %Q{"#{input}"}
    end
    STRING = string_validation_block

    # Same as string but allows nil.  Note the special
    # behavior of the nil string '~' -- rather than
    # being treated as a string, it is processed as nil
    # to be consistent with the other [class]_or_nil
    # methods.
    #
    #   string_or_nil.call('~')   # => nil
    #   string_or_nil.call(nil)   # => nil
    def string_or_nil(); STRING_OR_NIL; end
    string_or_nil_validation_block = lambda do |input|
      input = validate(input, [String, nil])
      case input
      when nil, '~' then nil 
      else eval %Q{"#{input}"}
      end
    end
    STRING_OR_NIL = string_or_nil_validation_block

    # Returns a block that checks the input is a symbol.
    # String inputs are loaded as yaml first.
    #
    #   symbol.class              # => Proc
    #   symbol.call(:sym)         # => :sym
    #   symbol.call(':sym')       # => :sym
    #   symbol.call(nil)          # => ValidationError
    #   symbol.call('str')        # => ValidationError
    #
    def symbol(); SYMBOL; end
    SYMBOL = yaml(Symbol)

    # Same as symbol but allows nil:
    #
    #   symbol_or_nil.call('~')   # => nil
    #   symbol_or_nil.call(nil)   # => nil
    def symbol_or_nil(); SYMBOL_OR_NIL; end
    SYMBOL_OR_NIL = yaml(Symbol, nil)

    # Returns a block that checks the input is true, false or nil.
    # String inputs are loaded as yaml first.
    #
    #   boolean.class             # => Proc
    #   boolean.call(true)        # => true
    #   boolean.call(false)       # => false
    #   boolean.call(nil)         # => nil
    #
    #   boolean.call('true')      # => true
    #   boolean.call('yes')       # => true
    #   boolean.call('FALSE')     # => false
    #
    #   boolean.call(1)           # => ValidationError
    #   boolean.call("str")       # => ValidationError
    #
    def boolean(); BOOLEAN; end
    BOOLEAN = yaml(true, false, nil)

    # Same as boolean.
    def switch(); SWITCH; end
    
    # default attributes {:type => :switch}
    SWITCH = yaml(true, false, nil)
    register SWITCH, :type => :switch
    
    # Same as boolean.
    def flag(); FLAG; end
    
    # default attributes {:type => :flag}
    FLAG = yaml(true, false, nil)
    register FLAG, :type => :flag

    # Returns a block that checks the input is an array.
    # String inputs are loaded as yaml first.
    #
    #   array.class               # => Proc
    #   array.call([1,2,3])       # => [1,2,3]
    #   array.call('[1, 2, 3]')   # => [1,2,3]
    #   array.call(nil)           # => ValidationError
    #   array.call('str')         # => ValidationError
    #
    def array(); ARRAY; end
    
    # default attributes {:arg_name => "'[a, b, c]'"}
    ARRAY = yaml(Array)
    register ARRAY, :arg_name => "'[a, b, c]'"

    # Same as array but allows nil:
    #
    #   array_or_nil.call('~')    # => nil
    #   array_or_nil.call(nil)    # => nil
    def array_or_nil(); ARRAY_OR_NIL; end
    
    # default attributes {:arg_name => "'[a, b, c]'"}
    ARRAY_OR_NIL = yaml(Array, nil)
    register ARRAY_OR_NIL, :arg_name => "'[a, b, c]'"

    # Returns a block that checks the input is an array,
    # then yamlizes each string value of the array.
    #
    #   list.class                # => Proc
    #   list.call([1,2,3])        # => [1,2,3]
    #   list.call(['1', 'str'])   # => [1,'str']
    #   list.call('str')          # => ValidationError
    #   list.call(nil)            # => ValidationError
    #
    def list(); LIST; end
    list_block = lambda do |input|
      validate(input, [Array]).collect do |arg| 
        arg.kind_of?(String) ? yamlize(arg) : arg
      end
    end
    
    # default attributes {:type => :list, :split => ','}
    LIST = list_block
    register LIST, :type => :list, :split => ','
    
    # Returns a block that checks the input is a hash.
    # String inputs are loaded as yaml first.
    #
    #   hash.class                     # => Proc
    #   hash.call({'key' => 'value'})  # => {'key' => 'value'}
    #   hash.call('key: value')        # => {'key' => 'value'}
    #   hash.call(nil)                 # => ValidationError
    #   hash.call('str')               # => ValidationError
    #
    def hash(); HASH; end
    
    # default attributes {:arg_name => "'{one: 1, two: 2}'"}
    HASH = yaml(Hash)
    register HASH, :arg_name => "'{one: 1, two: 2}'"

    # Same as hash but allows nil:
    #
    #   hash_or_nil.call('~')          # => nil
    #   hash_or_nil.call(nil)          # => nil
    def hash_or_nil(); HASH_OR_NIL; end
    
    # default attributes {:arg_name => "'{one: 1, two: 2}'"}
    HASH_OR_NIL = yaml(Hash, nil)
    register HASH_OR_NIL, :arg_name => "'{one: 1, two: 2}'"

    # Returns a block that checks the input is an integer.
    # String inputs are loaded as yaml first.
    #
    #   integer.class             # => Proc
    #   integer.call(1)           # => 1
    #   integer.call('1')         # => 1
    #   integer.call(1.1)         # => ValidationError
    #   integer.call(nil)         # => ValidationError
    #   integer.call('str')       # => ValidationError
    #
    def integer(); INTEGER; end
    INTEGER = yaml(Integer)

    # Same as integer but allows nil:
    #
    #   integer_or_nil.call('~')  # => nil
    #   integer_or_nil.call(nil)  # => nil
    def integer_or_nil(); INTEGER_OR_NIL; end
    INTEGER_OR_NIL = yaml(Integer, nil)

    # Returns a block that checks the input is a float.
    # String inputs are loaded as yaml first.
    #
    #   float.class               # => Proc
    #   float.call(1.1)           # => 1.1
    #   float.call('1.1')         # => 1.1
    #   float.call('1.0e+6')      # => 1e6
    #   float.call(1)             # => ValidationError
    #   float.call(nil)           # => ValidationError
    #   float.call('str')         # => ValidationError
    #
    def float(); FLOAT; end
    FLOAT = yaml(Float)

    # Same as float but allows nil:
    #
    #   float_or_nil.call('~')    # => nil
    #   float_or_nil.call(nil)    # => nil
    def float_or_nil(); FLOAT_OR_NIL; end
    FLOAT_OR_NIL = yaml(Float, nil)

    # Returns a block that checks the input is a number.
    # String inputs are loaded as yaml first.
    #
    #   num.class               # => Proc
    #   num.call(1.1)           # => 1.1
    #   num.call(1)             # => 1
    #   num.call(1e6)           # => 1e6
    #   num.call('1.1')         # => 1.1
    #   num.call('1.0e+6')      # => 1e6
    #   num.call(nil)           # => ValidationError
    #   num.call('str')         # => ValidationError
    #
    def num(); NUMERIC; end
    NUMERIC = yaml(Numeric)

    # Same as num but allows nil:
    #
    #   num_or_nil.call('~')    # => nil
    #   num_or_nil.call(nil)    # => nil
    def num_or_nil(); NUMERIC_OR_NIL; end
    NUMERIC_OR_NIL = yaml(Numeric, nil)

    # Returns a block that checks the input is a regexp.
    # String inputs are converted to regexps using
    # Regexp#new.
    #
    #   regexp.class              # => Proc
    #   regexp.call(/regexp/)     # => /regexp/
    #   regexp.call('regexp')     # => /regexp/
    #
    #   # use of ruby-specific flags can turn on/off 
    #   # features like case insensitive matching
    #   regexp.call('(?i)regexp') # => /(?i)regexp/
    #
    def regexp(); REGEXP; end
    regexp_block = lambda do |input|
      input = Regexp.new(input) if input.kind_of?(String)
      validate(input, [Regexp])
    end
    REGEXP = regexp_block

    # Same as regexp but allows nil. Note the special
    # behavior of the nil string '~' -- rather than
    # being converted to a regexp, it is processed as 
    # nil to be consistent with the other [class]_or_nil
    # methods.
    #
    #   regexp_or_nil.call('~')   # => nil
    #   regexp_or_nil.call(nil)   # => nil
    def regexp_or_nil(); REGEXP_OR_NIL; end
    regexp_or_nil_block = lambda do |input|
      input = case input
      when nil, '~' then nil
      when String then Regexp.new(input)
      else input
      end
  
      validate(input, [Regexp, nil])
    end
    REGEXP_OR_NIL = regexp_or_nil_block

    # Returns a block that checks the input is a range.
    # String inputs are split into a beginning and
    # end if possible, where each part is loaded as
    # yaml before being used to construct a Range.a
    #
    #   range.class               # => Proc
    #   range.call(1..10)         # => 1..10
    #   range.call('1..10')       # => 1..10
    #   range.call('a..z')        # => 'a'..'z'
    #   range.call('-10...10')    # => -10...10
    #   range.call(nil)           # => ValidationError
    #   range.call('1.10')        # => ValidationError
    #   range.call('a....z')      # => ValidationError
    #
    def range(); RANGE; end
    range_block = lambda do |input|
      if input.kind_of?(String) && input =~ /^([^.]+)(\.{2,3})([^.]+)$/
        input = Range.new(yamlize($1), yamlize($3), $2.length == 3) 
      end
      validate(input, [Range])
    end
    RANGE = range_block

    # Same as range but allows nil:
    #
    #   range_or_nil.call('~')    # => nil
    #   range_or_nil.call(nil)    # => nil
    def range_or_nil(); RANGE_OR_NIL; end
    range_or_nil_block = lambda do |input|
      input = case input
      when nil, '~' then nil
      when String
        if input =~ /^([^.]+)(\.{2,3})([^.]+)$/
          Range.new(yamlize($1), yamlize($3), $2.length == 3)
        else
          input
        end
      else input
      end
  
      validate(input, [Range, nil])
    end
    RANGE_OR_NIL = range_or_nil_block

    # Returns a block that checks the input is a Time. String inputs are 
    # loaded using Time.parse and then converted into times.  Parsed times 
    # are local unless specified otherwise.
    #
    #   time.class               # => Proc
    #
    #   now = Time.now
    #   time.call(now)           # => now
    #
    #   time.call('2008-08-08 20:00:00.00 +08:00').getutc.strftime('%Y/%m/%d %H:%M:%S')
    #   #  => '2008/08/08 12:00:00'
    #
    #   time.call('2008-08-08').strftime('%Y/%m/%d %H:%M:%S')
    #   #  => '2008/08/08 00:00:00'
    #
    #   time.call(1)             # => ValidationError
    #   time.call(nil)           # => ValidationError
    #
    # Warning: Time.parse will parse a valid time (Time.now)
    # even when no time is specified:
    #
    #   time.call('str').strftime('%Y/%m/%d %H:%M:%S')      
    #   # => Time.now.strftime('%Y/%m/%d %H:%M:%S')      
    #
    def time()
      # adding this here is a compromise to lazy-load the parse
      # method (autoload doesn't work since Time already exists)
      require 'time' unless Time.respond_to?(:parse)
      TIME
    end

    time_block = lambda do |input|
      input = Time.parse(input) if input.kind_of?(String)
      validate(input, [Time])
    end
    TIME = time_block

    # Same as time but allows nil:
    #
    #   time_or_nil.call('~')    # => nil
    #   time_or_nil.call(nil)    # => nil
    def time_or_nil()
      # adding this check is a compromise to autoload the parse 
      # method (autoload doesn't work since Time already exists)
      require 'time' unless Time.respond_to?(:parse)
      TIME_OR_NIL
    end

    time_or_nil_block = lambda do |input|
      input = case input
      when nil, '~' then nil
      when String then Time.parse(input)
      else input
      end
  
      validate(input, [Time, nil])
    end 
    TIME_OR_NIL = time_or_nil_block
    
  end
end