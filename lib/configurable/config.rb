require 'configurable/utils'

module Configurable
  
  # Configs setup config getters/setters, determine how to delegate read/write
  # operations to a receiver, and track metadata for presentation of configs
  # in various user contexts.
  class Config
    include Utils
    
    # The config name
    attr_reader :name
    
    # The reader method called on a receiver during get
    attr_reader :reader
    
    # The writer method called on a receiver during set
    attr_reader :writer
    
    # The default config value
    attr_reader :default
    
    # The short switch mapping to self
    attr_reader :short 
    
    # The long switch mapping to self
    attr_reader :long
    
    attr_reader :arg_name
    
    # The description printed by to_s
    attr_reader :desc
    
    attr_reader :hidden
    
    attr_reader :type
    
    # Initializes a new Config.
    def initialize(name, default=nil, reader=nil, writer=nil, attrs={})
      check_name(name)
      
      @name    = name
      @default = default
      @reader  = (reader || name).to_sym
      @writer  = (writer || "#{name}=").to_sym
      @short   = shortify(attrs[:short])
      @long    = longify(attrs.has_key?(:long) ? attrs[:long] : name)
      @argname = attrs[:argname]
      @desc    = attrs[:desc]
      @hidden  = attrs[:hidden]
      @type    = attrs[:type]
    end
    
    # Calls reader on the receiver and returns the result.
    def get(receiver)
      receiver.send(reader)
    end
    
    # Calls writer on the receiver with the value.
    def set(receiver, value)
      receiver.send(writer, value)
    end
    
    def define_reader(receiver_class)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        attr_reader :#{name}
        public :#{name}
      }, __FILE__, line
    end
    
    def define_writer(receiver_class, caster=nil)
      line = __LINE__ + 1
      receiver_class.class_eval %Q{
        def #{name}=(value)
          @#{name} = #{caster}(value)
        end
        public :#{name}=
      }, __FILE__, line
    end
    
    # Returns an array of non-nil switches mapping to self (ie [long, short]).
    def switches
      [long, short].compact
    end
    
    def parse(switch, value, argv=[], config={})
      unless value
        raise "no value provided for: #{switch}" if argv.empty?
        value = argv.shift
      end
      
      config[name] = value
      value
    end
    
    # Returns an inspect string.
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} default=#{default.inspect} >"
    end
    
    # Formats self as a help string for use on the command line.
    def to_s
      lines = Lazydoc::Utils.wrap(desc.to_s, 43)
      
      header =  "    #{short_str}#{long_str} #{arg_name}"
      header = header.length > 36 ? header.ljust(80) : (LINE_FORMAT % [header, lines.shift])
      
      if lines.empty?
        header
      else
        lines.collect! {|line| LINE_FORMAT % [nil, line] }
        "#{header}\n#{lines.join("\n")}"
      end
    end
    
    protected
    
    def check_name(name) # :nodoc
      unless name.kind_of?(Symbol)
        raise "invalid name: #{name.inspect} (not a Symbol)"
      end

      unless name.to_s =~ /\A\w+\z/
        raise NameError.new("invalid characters in name: #{name.inspect}")
      end
    end
    
    # helper returning short formatted for to_s
    def short_str # :nodoc:
      case
      when short && long
        "#{short}, "
      when short
        "#{short}"
      else 
        '    '
      end
    end
    
    # helper returning long formatted for to_s
    def long_str # :nodoc:
      long
    end
  end
end