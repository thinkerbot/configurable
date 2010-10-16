module Configurable
  
  # ConfigType encapsulates default attributes used as the basis for
  # attributes defined via config and nest.  Usually the attributes are only a
  # :caster and :uncaster, but other default attributes may be specified.
  #
  # Declared configs are matched to a ConfigType using one or more matchers
  # (usually classes) set on the ConfigType.
  class ConfigType
    class << self
      
      # Casts the input to a boolean ie:
      #
      #   true, 'true'   => true
      #   false, 'false  => false
      #
      # All other inputs raise an ArgumentError.
      def cast_to_bool(input)
        case input
        when true, false then input
        when 'true'      then true
        when 'false'     then false
        else raise ArgumentError, "invalid value for boolean: #{input.inspect}"
        end
      end
    end
    
    # An array of matchers (typically classes) used to identify defaults that
    # should be mapped to self.  Comparison to matchers is via case equality
    # (===).
    attr_reader :matchers
    
    # A hash of default attributes used as the basis of configs mapped to
    # self by a config declaration.
    attr_reader :default_attrs
    
    def initialize(*matchers)
      @matchers = matchers
      @default_attrs = matchers.last.kind_of?(Hash) ? matchers.pop : {}
    end
    
    # Sets the :caster attribute in default_attrs to the block.
    def cast(&caster)
      @default_attrs[:caster] = caster
      self
    end
    
    # Sets the :uncaster attribute in default_attrs to the block.
    def uncast(&uncaster)
      @default_attrs[:uncaster] = uncaster
      self
    end
    
    # Returns true if any of the matchers matches the value via case equality
    # (===).
    def ===(value)
      matchers.any? {|matcher| matcher === value }
    end
  end
end