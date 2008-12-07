require 'config_parser/option'
require 'config_parser/switch'

autoload(:Shellwords, 'shellwords')

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

  # A hash of (switch, Option) pairs mapping switches to
  # options.
  attr_reader :switches
  
  attr_reader :config
  
  attr_reader :default_config

  def initialize
    @options = []
    @switches = {}
    @config = {}
    @default_config = {}
  
    yield(self) if block_given?
  end

  # Returns an array of options registered with self.
  def options
    @options.select do |opt|
      opt.kind_of?(Option)
    end
  end

  # Adds a separator string to self.
  def separator(str)
    @options << str
  end

  # Registers the option with self by adding opt to options and mapping
  # the opt switches. Raises an error for conflicting keys and switches.
  def register(opt)
    @options << opt unless @options.include?(opt)

    opt.switches.each do |switch|
      case @switches[switch]
      when opt then next
      when nil then @switches[switch] = opt
      else raise ArgumentError, "switch is already mapped to a different option: #{switch}"
      end
    end

    opt
  end

  # Defines and registers a config with self.
  def define(key, default_value=nil, options={})
    # check for conflicts and register
    if default_config.has_key?(key)
      raise ArgumentError, "already set by a different option: #{key.inspect}"
    end
    default_config[key] = default_value
    
    block = case options[:type]
    when :switch then setup_switch(key, default_value, options)
    when :flag   then setup_flag(key, default_value, options)
    when :list   then setup_list(key, options)
    when nil     then setup_option(key, options)
    when respond_to?("setup_#{options[:type]}")
      send("setup_#{options[:type]}", key, default_value, options)
    else 
      raise ArgumentError, "unsupported type: #{options[:type]}"
    end
    
    on(options, &block)
  end
  
  def on(*args, &block)
    options = args.last.kind_of?(Hash) ? args.pop : {}
    args.each do |arg|
      # split switch arguments... descriptions
      # still won't match as a switch even
      # after a split
      switch, arg_name = arg.split(' ', 2)
      
      # determine the kind of argument specified
      key = case switch
      when SHORT_OPTION then :short
      when LONG_OPTION  then :long
      else :desc
      end
      
      # check for conflicts
      if options[key]
        raise ArgumentError, "conflicting #{key} options: [#{options[key]}, #{arg}]"
      end
      
      # set the option
      case key
      when :long, :short
        options[key] = switch
        options[:arg_name] = arg_name.strip if arg_name
      else
        options[key] = arg.strip
      end
    end
    
    # check if the option is specifying a Switch
    klass = case
    when options[:long].to_s =~ /^--\[no-\](.*)$/ 
      options[:long] = "--#{$1}"
      Switch
    else 
      Option
    end
    
    # instantiate and register the new option
    register klass.new(options, &block) 
  end
  
  # Parse is non-destructive to argv.  If a string argv is provided, parse
  # splits it into an array using Shellwords.
  #
  def parse(argv=ARGV, config={})
    @config = config
    argv = argv.kind_of?(String) ? Shellwords.shellwords(argv) : argv.dup
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
      # value = $4 || $3 (if arg matches SHORT_OPTION, value is $4 or $3 otherwise)
      arg =~ LONG_OPTION || arg =~ SHORT_OPTION || arg =~ ALT_SHORT_OPTION 
  
      # lookup the option
      unless option = @switches[$1]
        raise "unknown option: #{$1}"
      end
  
      option.parse($1, $4 || $3, argv)
    end
    
    default_config.each_pair do |key, default|
      config[key] = default unless config.has_key?(key)
    end
    
    args
  end
  
  # Same as parse, but removes parsed args from argv.
  def parse!(argv=ARGV, config={})
    argv.replace(parse(argv, config))
  end

  def to_s
    comments = @options.collect do |option|
      next unless option.respond_to?(:desc)
      option.desc.kind_of?(Lazydoc::Comment) ? option.desc : nil
    end.compact
    Lazydoc.resolve_comments(comments)
    
    @options.collect do |option|
      option.to_s.rstrip
    end.join("\n") + "\n"
  end
end