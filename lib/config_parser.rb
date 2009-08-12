require 'config_parser/option'
require 'config_parser/switch'

autoload(:Shellwords, 'shellwords')

# ConfigParser is the Configurable equivalent of 
# {OptionParser}[http://www.ruby-doc.org/core/classes/OptionParser.html]
# and uses a similar, simplified (see below) syntax to declare options.
#
#   opts = {}
#   parser = ConfigParser.new do |psr|
#     psr.on "-s", "--long LONG", "a standard option" do |value|
#       opts[:long] = value
#     end
#   
#     psr.on "--[no-]switch", "a switch" do |value|
#       opts[:switch] = value
#     end
#
#     psr.on "--flag", "a flag" do
#       # note: no value is parsed; the block 
#       # only executes if the flag is found
#       opts[:flag] = true
#     end
#   end
#
#   parser.parse("a b --long arg --switch --flag c")   # => ['a', 'b', 'c']
#   opts             # => {:long => 'arg', :switch => true, :flag => true}
#
# ConfigParser formalizes this pattern of setting values in a hash as they
# occur, and adds the ability to specify default values.  The syntax is
# not quite as friendly as for ordinary options, but meshes well with
# Configurable classes:
#
#   psr = ConfigParser.new
#   psr.define(:key, 'default', :desc => 'a standard option')
#
#   psr.parse('a b --key option c')                 # => ['a', 'b', 'c']
#   psr.config                                      # => {:key => 'option'}
#
#   psr.parse('a b c')                              # => ['a', 'b', 'c']
#   psr.config                                      # => {:key => 'default'}
#
# And now directly from a Configurable class, the equivalent of the
# original example:
#
#   class ConfigClass
#     include Configurable
#
#     config :long, 'default', :short => 's'  # a standard option
#     config :switch, false, &c.switch        # a switch
#     config :flag, false, &c.flag            # a flag
#   end
#
#   psr = ConfigParser.new
#   psr.add(ConfigClass.configurations)
#
#   psr.parse("a b --long arg --switch --flag c")   # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => true, :flag => true}
#
#   psr.parse("a b --long=arg --no-switch c")       # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => false, :flag => false}
#
#   psr.parse("a b -sarg c")                        # => ['a', 'b', 'c']
#   psr.config    # => {:long => 'arg', :switch => false, :flag => false}
#
# As you might expect, config attributes are used by ConfigParser to 
# correctly build a corresponding option.  In configurations like :switch, 
# the block implies the {:type => :switch} attribute and so the
# config is made into a switch-style option by ConfigParser.
#
# Use the to_s method to convert a ConfigParser into command line
# documentation:
#
#   "\nconfigurations:\n#{psr.to_s}"
#   # => %q{
#   # configurations:
#   #     -s, --long LONG                  a standard option
#   #         --[no-]switch                a switch
#   #         --flag                       a flag
#   # }
#
# ==== Simplifications
#
# ConfigParser simplifies the OptionParser syntax for 'on'.  ConfigParser does
# not support automatic conversion of values, gets rid of 'optional' arguments
# for options, and only supports a single description string.  Hence:
#
#   psr = ConfigParser.new
#  
#   # incorrect, raises error as this will look
#   # like multiple descriptions are specified
#   psr.on("--delay N", 
#          Float,
#          "Delay N seconds before executing")        # !> ArgumentError
#
#   # correct
#   psr.on("--delay N", "Delay N seconds before executing") do |value|
#     value.to_f
#   end
#
#   # this ALWAYS requires the argument and raises
#   # an error because multiple descriptions are
#   # specified
#   psr.on("-i", "--inplace [EXTENSION]",
#          "Edit ARGV files in place",
#          "  (make backup if EXTENSION supplied)")   # !> ArgumentError
#
#   # correct
#   psr.on("-i", "--inplace EXTENSION", 
#          "Edit ARGV files in place\n  (make backup if EXTENSION supplied)")
#
#
class ConfigParser
  class << self
    # Splits and nests compound keys of a hash.
    #
    #   ConfigParser.nest('key' => 1, 'compound:key' => 2)
    #   # => {
    #   # 'key' => 1,
    #   # 'compound' => {'key' => 2}
    #   # }
    #
    # Nest does not do any consistency checking, so be aware that results will
    # be ambiguous for overlapping compound keys.
    #
    #   ConfigParser.nest('key' => {}, 'key:overlap' => 'value')
    #   # =? {'key' => {}}
    #   # =? {'key' => {'overlap' => 'value'}}
    #
    def nest(hash, split_char=":")
      result = {}
      hash.each_pair do |compound_key, value|
        if compound_key.kind_of?(String)
          keys = compound_key.split(split_char)
      
          unless keys.length == 1
            nested_key = keys.pop
            nested_hash = keys.inject(result) {|target, key| target[key] ||= {}}
            nested_hash[nested_key] = value
            next
          end
        end
    
        result[compound_key] = value
      end
  
      result
    end
  end
  
  include Utils

  # A hash of (switch, Option) pairs mapping command line
  # switches like '-s' or '--long' to the Option that
  # handles them.
  attr_reader :switches
  
  # The hash receiving configurations produced by parse.
  attr_accessor :config
  
  # A hash of default configurations merged into config during parse.
  attr_reader :default_config

  # Initializes a new ConfigParser and passes it to the block, if given.
  def initialize(config={})
    @options = []
    @switches = {}
    @config = config
    @default_config = {}
  
    yield(self) if block_given?
  end
  
  # Returns the config value for key.
  def [](key)
    config[key]
  end
  
  # Sets the config value for key.
  def []=(key, value)
    config[key] = value
  end
  
  # Returns the nested form of config (see ConfigParser.nest).  Primarily
  # useful when nested configurations have been added with add.
  def nested_config
    ConfigParser.nest(config)
  end

  # Returns an array of the options registered with self.
  def options
    @options.select do |opt|
      opt.kind_of?(Option)
    end
  end

  # Adds a separator string to self, used in to_s.
  def separator(str)
    @options << str
  end

  # Registers the option with self by adding opt to options and mapping the
  # opt switches. Raises an error for conflicting switches.
  #
  # If override is specified, options with conflicting switches are removed
  # and no error is raised.  Note that this may remove multiple options.
  def register(opt, override=false)
    if override
      existing = opt.switches.collect do |switch|
        @switches.delete(switch)
      end
      @options -= existing
    end
    
    unless @options.include?(opt)
      @options << opt
    end
    
    opt.switches.each do |switch|
      case @switches[switch]
      when opt then next
      when nil then @switches[switch] = opt
      else raise ArgumentError, "switch is already mapped to a different option: #{switch}"
      end
    end

    opt
  end
  
  # Constructs an Option using args and registers it with self.  Args may
  # contain (in any order) a short switch, a long switch, and a description
  # string.  Either the short or long switch may signal that the option
  # should take an argument by providing an argument name.
  #
  #   psr = ConfigParser.new
  #
  #   # this option takes an argument
  #   psr.on('-s', '--long ARG_NAME', 'description') do |value|
  #     # ...
  #   end
  #
  #   # so does this one
  #   psr.on('-o ARG_NAME', 'description') do |value|
  #     # ...
  #   end
  #   
  #   # this option does not
  #   psr.on('-f', '--flag') do
  #     # ...
  #   end
  #
  # A switch-style option can be specified by prefixing the long switch with
  # '--[no-]'.  Switch options will pass true to the block for the positive
  # form and false for the negative form.
  #
  #   psr.on('--[no-]switch') do |value|
  #     # ...
  #   end
  #
  # Args may also contain a trailing hash defining all or part of the option:
  #
  #   psr.on('-k', :long => '--key', :desc => 'description')
  #     # ...
  #   end
  #
  def on(*args, &block)
    register new_option(args, &block)
  end
  
  # Same as on, but overrides options with overlapping switches.
  def on!(*args, &block)
    register new_option(args, &block), true
  end
  
  # Defines and registers a config-style option with self.  Define does not
  # take a block; the default value will be added to config, and any parsed
  # value will override the default.  Normally the key will be turned into
  # the long switch; specify an alternate long, a short, description, etc
  # using attributes.
  #
  #   psr = ConfigParser.new
  #   psr.define(:one, 'default')
  #   psr.define(:two, 'default', :long => '--long', :short => '-s')
  #
  #   psr.parse("--one one --long two")
  #   psr.config             # => {:one => 'one', :two => 'two'}
  #
  # Define support several types of configurations that define a special 
  # block to handle the values parsed from the command line.  See the 
  # 'setup_<type>' methods in Utils.  Any type with a corresponding setup
  # method is valid:
  #   
  #   psr = ConfigParser.new
  #   psr.define(:flag, false, :type => :flag)
  #   psr.define(:switch, false, :type => :switch)
  #   psr.define(:list, [], :type => :list)
  #
  #   psr.parse("--flag --switch --list one --list two --list three")
  #   psr.config             # => {:flag => true, :switch => true, :list => ['one', 'two', 'three']}
  #
  # New, valid types may be added by implementing new setup_<type> methods
  # following this pattern:
  #
  #   module SpecialType
  #     def setup_special(key, default_value, attributes)
  #       # modify attributes if necessary
  #       attributes[:long] = "--#{key}"
  #       attributes[:arg_name] = 'ARG_NAME'
  # 
  #       # return a block handling the input
  #       lambda {|input| config[key] = input.reverse }
  #     end
  #   end
  #
  #   psr = ConfigParser.new.extend SpecialType
  #   psr.define(:opt, false, :type => :special)
  #
  #   psr.parse("--opt value")
  #   psr.config             # => {:opt => 'eulav'}
  #
  # The :hidden type causes no configuration to be defined.  Raises an error if
  # key is already set by a different option.
  def define(key, default_value=nil, attributes={})
    # check for conflicts and register
    if default_config.has_key?(key)
      raise ArgumentError, "already set by a different option: #{key.inspect}"
    end
    default_config[key] = default_value
    
    # ensure setup does not modifiy input attributes
    attributes = attributes.dup
    
    block = case attributes[:type]
    when :switch then setup_switch(key, default_value, attributes)
    when :flag   then setup_flag(key, default_value, attributes)
    when :list, :list_select then setup_list(key, attributes)
    when :hidden then return nil
    else
      if respond_to?("setup_#{attributes[:type]}")
        send("setup_#{attributes[:type]}", key, default_value, attributes)
      else
        setup_option(key, attributes)
      end
    end
    
    on(attributes, &block)
  end
  
  # Adds a hash of delegates (for example the configurations for a Configurable
  # class) to self.  Delegates will be sorted by their :declaration_order
  # attribute, then added like:
  #
  #   define(key, delegate.default, delegate.attributes)
  #
  # ==== Nesting
  #
  # When you nest Configurable classes, a special syntax is necessary to
  # specify nested configurations in a flat format compatible with the
  # command line.  As such, nested delegates, ie delegates with a 
  # DelegateHash as a default value, are recursively added with their
  # key as a prefix.  For instance:
  #
  #   delegate_hash = DelegateHash.new(:key => Delegate.new(:reader))
  #   delegates = {}
  #   delegates[:nest] = Delegate.new(:reader, :writer=, delegate_hash)
  #
  #   psr = ConfigParser.new
  #   psr.add(delegates)
  #   psr.parse('--nest:key value')
  #
  #   psr.config                 # => {'nest:key' => 'value'}
  #   psr.nested_config          # => {'nest' => {'key' => 'value'}}
  #
  # Side note: The fact that all the keys end up as strings underscores
  # the importance of having indifferent access for delegates.  If you
  # set use_indifferent_access(false), be prepared to symbolize nested
  # keys as necessary.
  #
  def add(delegates, nesting=nil)
    delegates.each_pair do |key, delegate|
      key = nesting ? "#{nesting}:#{key}" : key
      default = delegate.default(false)
      
      if delegate.is_nest?
        unless delegate[:type] == :hidden
          add(default.delegates, key)
        end
      else
        define(key, default, delegate.attributes)
      end
    end
  end
  
  # Parses options from argv in a non-destructive manner and returns an
  # array of arguments remaining after options have been removed. If a 
  # string argv is provided, it will be splits into an array using 
  # Shellwords.
  #
  # ==== Options
  #
  # clear_config:: clears the currently parsed configs (true)
  # add_defaults:: adds the default values to config (true)
  # ignore_unknown_options:: causes unknown options to be ignored (false)
  #
  def parse(argv=ARGV, options={})
    argv = argv.dup unless argv.kind_of?(String)
    parse!(argv, options)
  end
  
  DEFAULT_PARSE_OPTIONS = {
    :clear_config => true,
    :add_defaults => true,
    :ignore_unknown_options => false
  }
  
  # Same as parse, but removes parsed args from argv.
  def parse!(argv=ARGV, options={})
    options = DEFAULT_PARSE_OPTIONS.merge(options)
    
    config.clear if options[:clear_config]
    argv = Shellwords.shellwords(argv) if argv.kind_of?(String)
    args = []
    
    while !argv.empty?
      arg = argv.shift
  
      # determine if the arg is an option
      unless arg.kind_of?(String) && arg[0] == ?-
        args << arg
        next
      end
      
      # add the remaining args and break
      # for the option break
      if arg == OPTION_BREAK
        args.concat(argv)
        break
      end
  
      # split the arg...
      # switch= $1
      # value = $2
      arg =~ LONG_OPTION || arg =~ SHORT_OPTION || arg =~ ALT_SHORT_OPTION 
  
      # lookup the option
      unless option = @switches[$1]
        if options[:ignore_unknown_options]
          args << arg
          next
        end
        
        raise "unknown option: #{$1 || arg}"
      end
  
      option.parse($1, $2, argv)
    end
    
    default_config.each_pair do |key, default|
      config[key] = default unless config.has_key?(key)
    end if options[:add_defaults]
    
    argv.replace(args)
    argv
  end
  
  # Converts the options and separators in self into a help string suitable for
  # display on the command line.
  def to_s
    @options.collect do |option|
      option.to_s.rstrip
    end.join("\n") + "\n"
  end
  
  protected
  
  # helper to parse an option from an argv.  new_option is used
  # by on and on! to generate options
  def new_option(argv, &block) # :nodoc:
    attributes = argv.last.kind_of?(Hash) ? argv.pop : {}
    argv.each do |arg|
      # split switch arguments... descriptions
      # still won't match as a switch even
      # after a split
      switch, arg_name = arg.kind_of?(String) ? arg.split(' ', 2) : arg
      
      # determine the kind of argument specified
      key = case switch
      when SHORT_OPTION then :short
      when LONG_OPTION  then :long
      else :desc
      end
      
      # check for conflicts
      if attributes[key]
        raise ArgumentError, "conflicting #{key} options: [#{attributes[key].inspect}, #{arg.inspect}]"
      end
      
      # set the option attributes
      case key
      when :long, :short
        attributes[key] = switch
        attributes[:arg_name] = arg_name if arg_name
      else
        attributes[key] = arg
      end
    end
    
    # check if a switch-style option is specified
    klass = case
    when attributes[:long].to_s =~ /^--\[no-\](.*)$/ 
      attributes[:long] = "--#{$1}"
      Switch
    else 
      Option
    end
    
    klass.new(attributes, &block)
  end
end