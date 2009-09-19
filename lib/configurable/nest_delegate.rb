require 'configurable/delegate'

module Configurable
  class NestDelegate < Delegate
    
    attr_reader :nest_class
    
    def initialize(nest_class, reader, writer="#{reader}=", init=true, attributes={})
      self.nest_class = nest_class
      self.reader = reader
      self.writer = writer
      
      @init = init
      @attributes = attributes
    end
    
    def default
      default = {}
      nest_class.configurations.each_pair do |key, delegate|
        default[key] = delegate.default
      end
      default
    end
    
    def get(receiver)
      receiver.send(reader).config
    end
    
    def set(receiver, value)
      if value.kind_of?(nest_class)
        receiver.send(writer, value)
      else
        configurable = receiver.send(reader) || init(receiver)
        configurable.reconfigure(value)
      end
    end
    
    def init(receiver)
      receiver.send(writer, nest_class.new)
    end
    
    def inspect
      "#<#{self.class}:#{object_id} reader=#{reader} writer=#{writer} nest_class=#{nest_class.inspect} >"
    end
    
    protected
    
    def nest_class=(nest_class)
      unless nest_class.kind_of?(Class) && nest_class.ancestors.include?(Configurable)
        raise ArgumentError, "not a Configurable: #{nest_class}"
      end
      
      @nest_class = nest_class
    end
  end
end