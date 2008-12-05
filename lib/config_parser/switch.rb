class ConfigParser 
  class Switch < Option
    attr_reader :negative_long

    def initialize(options={})
      super
      raise ArgumentError, "arg_name specified for switch: #{arg_name}" if arg_name
      raise ArgumentError, "no long specified" unless long
      @negative_long = Utils.longify("no-#{long[2,long.length-2]}")
    end

    def switches
      [long, negative_long, short].compact
    end

    def parse(switch, value, argv)
      raise "value specified for switch" if value
      value = (switch == negative_long ? false : true)
      block ? block.call(value) : value
    end

    def to_s
      short_str = short ? short + ',' : '   '
      long_str = long ? "--[no-]#{long[2,long.length-2]}" : ''
      desc_str = desc.kind_of?(Lazydoc::Comment) ? desc.trailer : desc
      "%-37s%-43s" % ["    #{short_str} #{long_str}", desc_str]
    end
  end
end