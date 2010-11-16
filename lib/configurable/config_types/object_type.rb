module Configurable
  module ConfigTypes
    class ObjectType
      class << self
        attr_reader :matchers
      
        def inherited(base) # :nodoc:
          unless base.instance_variable_defined?(:@matchers)
            base.instance_variable_set(:@matchers, matchers.dup)
          end
        end
        
        def subclass(*matchers, &caster)
          attrs = matchers.last.kind_of?(Hash) ? matchers.pop : {}
        
          subclass = Class.new(self)
          subclass.matches(matchers)
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
      
        def matches(*matchers)
          @matchers = matchers
          self
        end
      
        def matches?(value)
          matchers.any? {|matcher| matcher === value }
        end
      end
      matches()
      
      def initialize(attrs={})
      end
      
      def cast(input)
        input
      end
      
      def uncast(value)
        value
      end
    end
  end
end