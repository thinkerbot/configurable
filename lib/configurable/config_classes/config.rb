require 'configurable/config_types'

module Configurable
  module ConfigClasses
    # ConfigClasses are used by ConfigHash to delegate get/set configs on a
    # receiver. They also track metadata for interacting with configs from
    # user interfaces.  In particular configs allow the specification of a
    # word-based name as well as a caster/uncaster pair to translate string
    # inputs from config files, web forms, or command-line options to an
    # appropriate object and back again.
    class Config
      include ConfigTypes
      
      # The config key, used as a hash key for access.
      attr_reader :key
    
      # The config name used in interfaces where only word-based names are
      # appropriate. Names are strings consisting of only word characters.
      attr_reader :name
    
      # The reader method called on a receiver during get.
      attr_reader :reader
    
      # The writer method called on a receiver during set.
      attr_reader :writer
    
      # The caster which translates an input to a config value.  Must respond
      # to call if specified.
      attr_reader :caster
    
      # The uncaster which translates a config value to an input. Must respond
      # to call if specified.
      attr_reader :uncaster
    
      # The default config value.
      attr_reader :default
    
      # A validator for the config.  Must respond to include if present.
      attr_reader :options
      
      # A hash of any other attributes used to format self in user interfaces
      # (ex :long and :short for command-line options).  Attributes are frozen
      # during initialization.
      attr_reader :attrs
      
      # The config type for self (defaults to an ObjectType)
      attr_reader :type
      
      # Initializes a new Config.  Specify attributes like default, reader,
      # writer, caster, etc. within attrs.
      def initialize(key, attrs={})
        @key      = key
        @name     = attrs[:name] || @key.to_s
        check_name(@name)
        
        attrs[:default] = nil unless attrs.has_key?(:default)
        @default  = attrs[:default]
        @type     = attrs[:type] || ObjectType.new(attrs)
         
        @reader   = (attrs[:reader] ||= name).to_sym
        @writer   = (attrs[:writer] ||= "#{name}=").to_sym
        @attrs    = attrs.freeze
      end
    
      # Get the specified attribute from attrs.
      def [](key)
        attrs[key]
      end
    
      # Calls reader on the receiver and returns the result.
      def get(receiver)
        receiver.send(reader)
      end
    
      # Calls writer on the receiver with the value.
      def set(receiver, value)
        receiver.send(writer, value)
      end
    
      def cast(input)
        type.cast(input)
      end
      
      def uncast(value)
        type.uncast(value)
      end
      
      def valid?(value)
        errors(value).nil?
      end
      
      def errors(value)
        type.errors(value)
      end
      
      # Imports a config from source into target by casting the input keyed
      # by name in source and setting the result into target by key.
      def import(source, target={})
        if source.has_key?(name)
          input = source[name]
          target[key] = cast(input)
        end
        
        target
      end
    
      # Exports a config from source into target by uncasting the value keyed
      # by key in source and setting the resulting output into target by name.
      def export(source, target={})
        if source.has_key?(key)
          value = source[key]
          target[name] = uncast(value)
        end
        
        target
      end
      
      def validate(source, errors={})
        if source.has_key?(key)
          value = source[key]
          
          if output = errors(value)
            errors[key] = output
          end
        end
        
        errors
      end
    
      # Returns an inspect string.
      def inspect
        "#<#{self.class}:#{object_id} key=#{key} name=#{name} default=#{default.inspect} reader=#{reader} writer=#{writer} >"
      end
    
      protected
    
      def check_name(name) # :nodoc
        unless name.kind_of?(String)
          raise "invalid name: #{name.inspect} (not a String)"
        end

        unless name =~ /\A\w+\z/
          raise NameError.new("invalid characters in name: #{name.inspect}")
        end
      end
    end
  end
end