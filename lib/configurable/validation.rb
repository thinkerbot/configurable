autoload(:YAML, 'yaml')

module Configurable
  # A hash of (block, default attributes) for config blocks.  The 
  # attributes for nil will be merged with those for the block.
  DEFAULT_ATTRIBUTES = Hash.new({})
  DEFAULT_ATTRIBUTES[nil] = {:reader => true, :writer => true}
  
  # Validation generates blocks for common validations and transformations of 
  # configurations set through Configurable.  In general these blocks load
  # string inputs as YAML and validate the results; non-string inputs are
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
    
    # Raised when validate_api fails.
    class ApiError < ArgumentError
      def initialize(input, methods)
        super case 
        when methods.empty?
          "no api specified"
        else
          "expected api #{methods.inspect} for: #{input.inspect}"
        end
      end
    end

    module_function

    # Registers the default attributes with the specified block
    # in Configurable::DEFAULT_ATTRIBUTES.
    def register(attributes={}, &block)
      DEFAULT_ATTRIBUTES[block] = attributes
      block
    end
    
    # Registers the default attributes of the source as the attributes
    # of the target.  Overridding or additional attributes are merged
    # to the defaults.
    def register_as(source, target, attributes={})
      DEFAULT_ATTRIBUTES[target] = DEFAULT_ATTRIBUTES[source].dup.merge!(attributes)
      target
    end
    
    # Returns the attributes registered to the block.
    def attributes(block)
      DEFAULT_ATTRIBUTES[block] || {}
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
    # A block may be provided to handle invalid inputs; if provided it will be
    # called with the input and a ValidationError will not be raised unless the
    # block returns false.  Note the validations input must be an Array or nil;
    # validate will raise an ArgumentError otherwise.  All inputs are
    # considered VALID if validations == nil.
    def validate(input, validations)
      case validations
      when Array
  
        case input
        when *validations then input
        else 
          if block_given? && yield(input)
            input
          else
            raise ValidationError.new(input, validations)
          end
        end
    
      when nil then input
      else raise ArgumentError, "validations must be an array of valid inputs or nil"
      end
    end
    
    # Returns input if it responds to all of the specified methods.  Raises an
    # ApiError otherwise.  For example:
    #
    #   validate_api(10, [:to_s, :to_f])             # => 10
    #   validate_api(Object.new, [:to_s, :to_f])     # !> ApiError
    #
    # A block may be provided to handle invalid inputs; if provided it will be
    # called with the input and an ApiError will not be raised unless the 
    # block returns false.  Note the methods input must be an Array or nil;
    # validate_api will raise an ArgumentError otherwise.  All inputs are
    # considered VALID if methods == nil.
    def validate_api(input, methods)
      case methods
      when Array
        unless methods.all? {|m| input.respond_to?(m) }
          if block_given? && yield(input)
            input
          else
            raise ApiError.new(input, methods)
          end
        end
      when nil
      else raise ArgumentError, "methods must be an array or nil"
      end
      
      input
    end
    
    # Helper to load the input into a valid object.  If a valid object is not
    # loaded as YAML, or if an error occurs, the original input is returned.
    def load_if_yaml(input, *validations)
      begin
        yaml = YAML.load(input)
        case yaml
        when *validations then yaml
        else input
        end
      rescue(ArgumentError)
        input
      end
    end
    
    # Returns a block that calls validate using the block input
    # and validations.
    def check(*validations)
      lambda {|input| validate(input, validations) }
    end
    
    # Guesses and returns a block for the example value.
    def guess(value)
      case value
      when true    then switch
      when false   then flag
      when Numeric then numeric
      when Array   then list
      when String  then string
      when Time    then time
      when Range   then range
      when Regexp  then regexp
      else yaml
      end
    end
    
    # Returns a block that calls validate_api using the block input
    # and methods.
    def api(*methods)
      lambda do |input|
        validate_api(input, methods)
      end
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
      validations = nil if validations.empty?
      lambda do |input|
        input = YAML.load(input) if input.kind_of?(String)
        validate(input, validations)
      end
    end

    # Returns a block that checks the input is a string.
    #
    #   string.class              # => Proc
    #   string.call('str')        # => 'str'
    #   string.call(nil)          # => ValidationError
    #   string.call(:sym)         # => ValidationError
    #
    def string(); STRING; end
    string_validation_block = lambda do |input|
      validate(input, [String])
    end
    
    # default attributes {:type => :string, :example => "string"}
    STRING = string_validation_block
    register :type => :string, :example => "string", &STRING
    
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
      else input
      end
    end
    
    STRING_OR_NIL = string_or_nil_validation_block
    register_as STRING, STRING_OR_NIL
    
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
    
    # default attributes {:type => :symbol, :example => ":sym"}
    SYMBOL = yaml(Symbol)
    register :type => :symbol, :example => ":sym", &SYMBOL
    
    # Same as symbol but allows nil:
    #
    #   symbol_or_nil.call('~')   # => nil
    #   symbol_or_nil.call(nil)   # => nil
    def symbol_or_nil(); SYMBOL_OR_NIL; end
    
    SYMBOL_OR_NIL = yaml(Symbol, nil)
    register_as SYMBOL, SYMBOL_OR_NIL
    
    # Returns a block that checks the input is a symbol.
    # String inputs are directly converted to a symbol.
    #
    #   strbol.class              # => Proc
    #   strbol.call(:sym)         # => :sym
    #   strbol.call(':sym')       # => :":sym"
    #   strbol.call('str')        # => :sym
    #   strbol.call(nil)          # => ValidationError
    #
    def strbol(); STRBOL; end

    # default attributes {:type => :symbol, :example => ":sym"}
    STRBOL = lambda do |input|
      if input.kind_of?(String)
        input = input.to_sym
      end
      
      validate(input, [Symbol])
    end
    register :type => :symbol, :example => ":sym", &STRBOL

    # Same as strbol but allows nil.  Tilde is considered a string
    # equivalent of nil (this behavior is consistent with the YAML
    # methods but obviously inconsistent with the strbol behavior).
    #
    #   strbol_or_nil.call('~')   # => nil
    #   strbol_or_nil.call(nil)   # => nil
    def strbol_or_nil(); STRBOL_OR_NIL; end

    STRBOL_OR_NIL = lambda do |input|
      input = case input
      when "~"    then nil
      when String then input.to_sym
      else input
      end
      
      validate(input, [Symbol, nil])
    end
    register_as STRBOL, STRBOL_OR_NIL
    
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
    
    # default attributes {:type => :boolean, :example => "true, yes"}
    BOOLEAN = yaml(true, false, nil)
    register :type => :boolean, :example => "true, yes", &BOOLEAN

    # Same as boolean.
    def switch(); SWITCH; end
    
    # default attributes {:type => :switch}
    SWITCH = yaml(true, false, nil)
    register :type => :switch, &SWITCH
    
    # Same as boolean.
    def flag(); FLAG; end
    
    # default attributes {:type => :flag}
    FLAG = yaml(true, false, nil)
    register :type => :flag, &FLAG

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
    
    # default attributes {:type => :array, :example => "[a, b, c]"}
    ARRAY = yaml(Array)
    register :type => :array, :example => "[a, b, c]", &ARRAY

    # Same as array but allows nil:
    #
    #   array_or_nil.call('~')    # => nil
    #   array_or_nil.call(nil)    # => nil
    def array_or_nil(); ARRAY_OR_NIL; end
    
    ARRAY_OR_NIL = yaml(Array, nil)
    register_as ARRAY, ARRAY_OR_NIL

    # Returns a block that checks the input is an array,
    # then yamlizes each string value of the array.
    #
    #   list.class                # => Proc
    #   list.call([1,2,3])        # => [1,2,3]
    #   list.call(['1', 'str'])   # => [1,'str']
    #   list.call('str')          # => ValidationError
    #   list.call(nil)            # => ValidationError
    #
    def list(&validation)
      return LIST unless validation
      
      block = lambda do |input|
        args = validate(input, [Array]).collect do |arg| 
          arg.kind_of?(String) ? YAML.load(arg) : arg
        end
        args.collect! {|arg| validation.call(arg) }
        args
      end
      
      register_as(LIST, block, :validation => attributes(validation))
    end
    
    list_block = lambda do |input|
      validate(input, [Array]).collect do |arg| 
        arg.kind_of?(String) ? YAML.load(arg) : arg
      end
    end
    
    # default attributes {:type => :list, :split => ','}
    LIST = list_block
    register :type => :list, :split => ',', &LIST
    
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
    
    # default attributes {:type => :hash, :example => "{one: 1, two: 2}"}
    HASH = yaml(Hash)
    register :type => :hash, :example => "{one: 1, two: 2}", &HASH

    # Same as hash but allows nil:
    #
    #   hash_or_nil.call('~')          # => nil
    #   hash_or_nil.call(nil)          # => nil
    def hash_or_nil(); HASH_OR_NIL; end
    
    HASH_OR_NIL = yaml(Hash, nil)
    register_as HASH, HASH_OR_NIL

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
    
    # default attributes {:type => :integer, :example => "2"}
    INTEGER = yaml(Integer)
    register :type => :integer, :example => "2", &INTEGER
    
    # Same as integer but allows nil:
    #
    #   integer_or_nil.call('~')  # => nil
    #   integer_or_nil.call(nil)  # => nil
    def integer_or_nil(); INTEGER_OR_NIL; end
    
    INTEGER_OR_NIL = yaml(Integer, nil)
    register_as INTEGER, INTEGER_OR_NIL
    
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
    
    # default attributes {:type => :float, :example => "2.2, 2.0e+2"}
    FLOAT = yaml(Float)
    register :type => :float, :example => "2.2, 2.0e+2", &FLOAT
    
    # Same as float but allows nil:
    #
    #   float_or_nil.call('~')    # => nil
    #   float_or_nil.call(nil)    # => nil
    def float_or_nil(); FLOAT_OR_NIL; end

    FLOAT_OR_NIL = yaml(Float, nil)
    register_as FLOAT, FLOAT_OR_NIL

    # Returns a block that checks the input is a number.
    # String inputs are loaded as yaml first.
    #
    #   numeric.class               # => Proc
    #   numeric.call(1.1)           # => 1.1
    #   numeric.call(1)             # => 1
    #   numeric.call(1e6)           # => 1e6
    #   numeric.call('1.1')         # => 1.1
    #   numeric.call('1.0e+6')      # => 1e6
    #   numeric.call(nil)           # => ValidationError
    #   numeric.call('str')         # => ValidationError
    #
    def numeric(); NUMERIC; end
    
    # default attributes {:type => :numeric, :example => "2, 2.2, 2.0e+2"}
    NUMERIC = yaml(Numeric)
    register :type => :numeric, :example => "2, 2.2, 2.0e+2", &NUMERIC
    
    # Same as numeric but allows nil:
    #
    #   numeric_or_nil.call('~')    # => nil
    #   numeric_or_nil.call(nil)    # => nil
    def numeric_or_nil(); NUMERIC_OR_NIL; end
    
    NUMERIC_OR_NIL = yaml(Numeric, nil)
    register_as NUMERIC, NUMERIC_OR_NIL

    # Returns a block that checks the input is a regexp. String inputs are
    # loaded as yaml; if the result is not a regexp, it is converted to
    # a regexp using Regexp#new.
    #
    #   regexp.class              # => Proc
    #   regexp.call(/regexp/)     # => /regexp/
    #   regexp.call('regexp')     # => /regexp/
    #
    #   yaml_str = '!ruby/regexp /regexp/'
    #   regexp.call(yaml_str)     # => /regexp/
    #
    #   # use of ruby-specific flags can turn on/off 
    #   # features like case insensitive matching
    #   regexp.call('(?i)regexp') # => /(?i)regexp/
    #
    def regexp(); REGEXP; end
    regexp_block = lambda do |input|
      if input.kind_of?(String)
        input = load_if_yaml(input, Regexp)
      end
      
      if input.kind_of?(String)
        input = Regexp.new(input)
      end
      
      validate(input, [Regexp])
    end
    
    # default attributes {:type => :regexp, :example => "/regexp/i"}
    REGEXP = regexp_block
    register :type => :regexp, :example => "/regexp/i", &REGEXP

    # Same as regexp but allows nil. Note the special behavior of the nil
    # string '~' -- rather than being converted to a regexp, it is processed
    # as nil to be consistent with the other [class]_or_nil methods.
    #
    #   regexp_or_nil.call('~')   # => nil
    #   regexp_or_nil.call(nil)   # => nil
    def regexp_or_nil(); REGEXP_OR_NIL; end
    regexp_or_nil_block = lambda do |input|
      case input
      when nil, '~' then nil
      else REGEXP[input]
      end
    end
    
    REGEXP_OR_NIL = regexp_or_nil_block
    register_as REGEXP, REGEXP_OR_NIL

    # Returns a block that checks the input is a range. String inputs are
    # loaded as yaml (a '!ruby/range' prefix is added before loading if
    # if it is not specified).
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
    #   yaml_str = "!ruby/range \nbegin: 1\nend: 10\nexcl: false\n"
    #   range.call(yaml_str)      # => 1..10
    #
    def range(); RANGE; end
    range_block = lambda do |input|
      if input.kind_of?(String)
        input = "!ruby/range #{input}" unless input =~ /\A\s*!ruby\/range\s/
        input = load_if_yaml(input, Range)
      end
      
      validate(input, [Range])
    end
    
    # default attributes {:type => :range, :example => "min..max"}
    RANGE = range_block
    register :type => :range, :example => "min..max", &RANGE
    
    # Same as range but allows nil:
    #
    #   range_or_nil.call('~')    # => nil
    #   range_or_nil.call(nil)    # => nil
    def range_or_nil(); RANGE_OR_NIL; end
    range_or_nil_block = lambda do |input|
      case input
      when nil, '~' then nil
      else RANGE[input]
      end
    end
    
    RANGE_OR_NIL = range_or_nil_block
    register_as RANGE, RANGE_OR_NIL

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
    
    # default attributes {:type => :time, :example => "2008-08-08 08:00:00"}
    TIME = time_block
    register :type => :time, :example => "2008-08-08 08:00:00", &TIME
    
    # Same as time but allows nil:
    #
    #   time_or_nil.call('~')    # => nil
    #   time_or_nil.call(nil)    # => nil
    def time_or_nil(); TIME_OR_NIL; end

    time_or_nil_block = lambda do |input|
      case input
      when nil, '~' then nil
      else TIME[input]
      end
    end 
    
    TIME_OR_NIL = time_or_nil_block
    register_as TIME, TIME_OR_NIL
    
    # Returns a block that only allows the specified options.  Select can take
    # a block that will validate the input individual value.
    #
    #   s = select(1,2,3, &integer)
    #   s.class                      # => Proc
    #   s.call(1)                    # => 1
    #   s.call('3')                  # => 3
    #
    #   s.call(nil)                  # => ValidationError
    #   s.call(0)                    # => ValidationError
    #   s.call('4')                  # => ValidationError
    #
    # The select block is registered with these default attributes: 
    #
    #  {:type => :select, :options => options}
    #
    def select(*options, &validation)
      register(
        :type => :select, 
        :options => options,
        :validation => attributes(validation)
      ) do |input|
        input = validation.call(input) if validation
        validate(input, options)
      end
    end
    
    # Returns a block that checks the input is an array, and that each member
    # of the array is included in options.  A block may be provided to validate
    # the individual values.
    #
    #   s = list_select(1,2,3, &integer)
    #   s.class                      # => Proc
    #   s.call([1])                  # => [1]
    #   s.call([1, '3'])             # => [1, 3]
    #   s.call([])                   # => []
    #
    #   s.call(1)                    # => ValidationError
    #   s.call([nil])                # => ValidationError
    #   s.call([0])                  # => ValidationError
    #   s.call(['4'])                # => ValidationError
    #
    # The list_select block is registered with these default attributes: 
    #
    #  {:type => :list_select, :options => options, :split => ','}
    #
    def list_select(*options, &validation)
      register( 
        :type => :list_select, 
        :options => options, 
        :split => ',',
        :validation => attributes(validation)
      ) do |input|
        args = validate(input, [Array])
        args.collect! {|arg| validation.call(arg) } if validation
        args.each {|arg| validate(arg, options) }
      end
    end
    
    # Returns a block validating the input is an IO, a string, or an integer.
    # String inputs are expected to be filepaths and integer inputs are expected
    # to be valid file descriptors, but io does not open an IO immediately.
    #
    #   io.class                     # => Proc
    #   io.call($stdout)             # => $stdout
    #   io.call('/path/to/file')     # => '/path/to/file'
    #   io.call(1)                   # => 1
    #   io.call(nil)                 # => ValidationError
    #
    # An IO api can be specified to allow other objects to be validated.  This
    # is useful for duck-typing an IO when a known subset of methods are needed.
    #
    #   array_io = io(:<<)
    #   array_io.call($stdout)       # => $stdout
    #   array_io.call([])            # => []
    #   array_io.call(nil)           # => ApiError
    #
    # Note that by default io configs will not be duplicated (duplicate IOs
    # flush separately, and this can result in disorder.  see
    # http://gist.github.com/88808).
    def io(*api)
      if api.empty?
        IO_OR_STRING
      else
        block = lambda do |input|
          validate(input, [IO, String, Integer]) do
            validate_api(input, api)
          end
        end
        
        register_as IO_OR_STRING, block
      end
    end
    
    # default attributes {:type => :io, :dup => false, :example => "/path/to/file"}
    IO_OR_STRING = check(IO, String, Integer)
    register :type => :io, :dup => false, :example => "/path/to/file", &IO_OR_STRING
    
    # Same as io but allows nil:
    #
    #   io_or_nil.call(nil)          # => nil
    #
    def io_or_nil(*api)
      if api.empty?
        IO_STRING_OR_NIL
      else
        block = lambda do |input|
          validate(input, [IO, String, Integer, nil]) do
            validate_api(input, api)
          end
        end
        
        register_as IO_STRING_OR_NIL, block
      end  
    end
    
    IO_STRING_OR_NIL = check(IO, String, Integer, nil)
    register_as IO_OR_STRING, IO_STRING_OR_NIL
  end
end