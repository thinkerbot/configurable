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
  # This syntax plays well with RDoc, which otherwise gets jacked when you do
  # it all in one step.
  module Validation

    # Raised when a Validation block fails.
    class ValidationError < ArgumentError
      def initialize(input, *validations)
        super "expected #{validations.inspect} but was: #{input.inspect}"
      end
    end

    module_function

    # Registers the default attributes with the specified block in
    # Configurable::DEFAULT_ATTRIBUTES.
    def register(attributes={}, &block)
      DEFAULT_ATTRIBUTES[block] = attributes
      block
    end

    # Registers the default attributes of the source as the attributes of the
    # target.  Overridding or additional attributes are merged to the
    # defaults.
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
    def validate(input, validations)
      case input
      when *validations then input
      else raise ValidationError.new(input, validations)
      end
    end

    # Returns a block that calls validate using the block input and
    # validations.
    def check(*validations)
      lambda {|input| validate(input, validations) }
    end

    # Guesses and returns a block for the example value.
    def guess(value)
      case value
      when true    then switch
      when false   then flag
      when Numeric then numeric
      when Array   then list(&guess(value.first))
      else string
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
    string_block = check(String)

    # default attributes {:type => :string, :example => "string"}
    STRING = string_block
    register :type => :string, :example => "string", &STRING

    # Same as string but allows nil.  Empty strings are interpreted as nil.
    #
    #   string_or_nil.call('')    # => nil
    #   string_or_nil.call(nil)   # => nil
    #
    def string_or_nil(); STRING_OR_NIL; end
    string_or_nil_block = lambda do |input|
      input = validate(input, [String, nil])
      (input.nil? || input == '') ? nil : input
    end

    STRING_OR_NIL = string_or_nil_block
    register_as STRING, STRING_OR_NIL

    # Returns a block that checks the input is true or false. String inputs
    # 'true' and 'false' are converted to their corresponding booleans.
    #
    #   switch.class             # => Proc
    #   switch.call(true)        # => true
    #   switch.call(false)       # => false
    #
    #   switch.call('true')      # => true
    #   switch.call('false')     # => false
    #
    #   switch.call(1)           # => ValidationError
    #   switch.call("str")       # => ValidationError
    #
    def switch(); SWITCH; end
    switch_block = lambda do |input|
      case input
      when true, false then input
      when 'true'      then true
      when 'false'     then false
      else validate(input, [true, false])
      end
    end

    # default attributes {:type => :switch}
    SWITCH = switch_block
    register :type => :switch, &SWITCH

    # Same as switch.
    def flag(); FLAG; end
    flag_block = lambda do |input|
      case input
      when true, false then input
      when 'true'      then true
      when 'false'     then false
      else validate(input, [true, false])
      end
    end

    # default attributes {:type => :flag}
    FLAG = flag_block
    register :type => :flag, &FLAG

    # Returns a block that checks the input is an integer. String inputs are
    # loaded as integers.
    #
    #   integer.class             # => Proc
    #   integer.call(1)           # => 1
    #   integer.call('1')         # => 1
    #   integer.call(1.1)         # => ValidationError
    #   integer.call(nil)         # => ValidationError
    #   integer.call('str')       # => ValidationError
    #
    def integer(); INTEGER; end
    integer_block = lambda do |input|
      if input.kind_of?(String)
        input = Integer(input) rescue input
      end
      
      validate(input, [Integer])
    end

    # default attributes {:type => :integer, :example => "2"}
    INTEGER = integer_block
    register :type => :integer, :example => "2", &INTEGER

    # Same as integer but allows nil.  Empty strings are converted to nil.
    #
    #   integer_or_nil.call('')   # => nil
    #   integer_or_nil.call(nil)  # => nil
    #
    def integer_or_nil(); INTEGER_OR_NIL; end
    integer_or_nil_block = lambda do |input|
      input = validate(input, [Integer, String, nil])
      (input.nil? || input == '') ? nil : Integer(input)
    end

    INTEGER_OR_NIL = integer_or_nil_block
    register_as INTEGER, INTEGER_OR_NIL

    # Returns a block that checks the input is a float. String inputs are
    # loaded as floats.
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
    float_block = lambda do |input|
      if input.kind_of?(String)
        input = Float(input) rescue input
      end
      
      validate(input, [Float])
    end

    # default attributes {:type => :float, :example => "2.2, 2.0e+2"}
    FLOAT = float_block
    register :type => :float, :example => "2.2, 2.0e+2", &FLOAT

    # Same as float but allows nil.  Empty strings are converted to nil.
    #
    #   float_or_nil.call('')     # => nil
    #   float_or_nil.call(nil)    # => nil
    #
    def float_or_nil(); FLOAT_OR_NIL; end
    float_or_nil_block = lambda do |input|
      input = validate(input, [Float, String, nil])
      (input.nil? || input == '') ? nil : Float(input)
    end

    FLOAT_OR_NIL = float_or_nil_block
    register_as FLOAT, FLOAT_OR_NIL

    # Returns a block that checks the input is an array.
    #
    #   list.class                # => Proc
    #   list.call([1,2,3])        # => [1,2,3]
    #   list.call('str')          # => ValidationError
    #   list.call(nil)            # => ValidationError
    #
    def list(&validation)
      return LIST unless validation
      
      block = lambda do |input|
        args = validate(input, [Array])
        args.collect! {|arg| validation.call(arg) }
        args
      end
      
      register_as(LIST, block, :validation => attributes(validation))
    end

    list_block = check(Array)

    # default attributes {:type => :list, :split => ','}
    LIST = list_block
    register :type => :list, :split => ',', &LIST

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
    #   {:type => :select, :options => options}
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
    #   {:type => :list_select, :options => options, :split => ','}
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
  end
end