module Configurable
  module ConfigTypes
    class ObjectType
      class << self
        attr_reader :default_attrs
        attr_reader :matchers
      
        def inherited(base) # :nodoc:
          unless base.instance_variable_defined?(:@default_attrs)
            base.instance_variable_set(:@default_attrs, default_attrs.dup)
          end

          unless base.instance_variable_defined?(:@matchers)
            base.instance_variable_set(:@matchers, matchers.dup)
          end
        end
        
        def subclass(*matchers, &caster)
          attrs = matchers.last.kind_of?(Hash) ? matchers.pop : {}
        
          subclass = Class.new(self)
          subclass.matches(matchers)
          subclass.attrs(attrs)
          subclass.cast(&caster)
          subclass
        end
      
        def cast(&block)
          define_method(:cast, &block) if block
          self
        end
      
        def uncast(&block)
          define_method(:uncast, &block) if block
          self
        end
      
        def errors(&block)
          define_method(:errors, &block) if block
          self
        end
      
        def attrs(attrs={})
          @default_attrs = attrs
          self
        end
        
        def matches(*matchers)
          @matchers = matchers
          self
        end
      
        def matches?(value)
          matchers.any? {|matcher| matcher === value }
        end
      end
      attrs()
      matches()
      
      attr_reader :attrs
      
      # A validator for the config.  Must respond to include if present.
      attr_reader :options
      
      def initialize(attrs={})
        @attrs = self.class.default_attrs.merge(attrs)
        @options = @attrs[:options]
        @attrs.freeze
      end
      
      def cast(input)
        input
      end
      
      def uncast(value)
        value
      end
      
      def errors(value)
        options && !options.include?(value) ? ["invalid value: #{value.inspect}"] : nil
      end
    end
  end
end