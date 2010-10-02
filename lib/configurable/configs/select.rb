module Configurable
  module Configs
    
    # Represents a config where the input is expected to be one of a specified
    # whitelist.  The default writer will enforce this constraints.
    class Select < Config
      
      # An array of allowed values for the config. Note the writer must do the
      # work of checking and enforcing this constraint.
      attr_reader :options
      
      def initialize(name, default=nil, reader=nil, writer=nil, attrs={})
        super
        @options = attrs[:options] || []
      end
      
      # Defines the default writer method on receiver_class, using the caster
      # to cast the input before setting it as the config value. The caster
      # should be a method name as this is the added code:
      #
      #   NAME_OPTIONS = options
      #
      #   def name=(value)
      #     value = caster(value)
      #
      #     unless NAME_OPTIONS.include?(value)
      #       raise ArgumentError, "invalid value for name: #{value.inspect}"
      #     end
      #
      #     @name = value
      #   end
      #   public :name=
      #
      # Notice options is set as a constant on the receiver class.
      def define_default_writer(receiver_class, caster=nil)
        options = define_default_options_constant(receiver_class)

        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(value)
            value = #{caster}(value)
            unless #{options}.include?(value)
              raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
            end
            @#{name} = value
          end
          public :#{name}=
        }, __FILE__, line
      end
      
      # Defines the default options constant used by the default writer.  The
      # added code is simply:
      #
      #   NAME_OPTIONS = options
      #
      def define_default_options_constant(receiver_class)
        const_name = "#{name}_OPTIONS".upcase
        receiver_class.const_set(const_name, options)
        const_name
      end
    end
  end
end