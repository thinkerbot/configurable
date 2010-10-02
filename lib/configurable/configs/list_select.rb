module Configurable
  module Configs
    
    # Represents a list style config where the input is expected to be an
    # Array, and each value is in a specified whitelist.  The default writer
    # will enforce these constraints.
    class ListSelect < Select
      
      # Defines the default writer method on receiver_class, using the caster
      # to to cast each input before setting the config value. The caster
      # should be a method name as this is the added code:
      #
      #   NAME_OPTIONS = options
      #
      #   def name=(values)
      #     unless values.kind_of?(Array)
      #       raise ArgumentError, "invalid value for name: #{values.inspect}"
      #     end
      #
      #     values.collect! {|value| caster(value) }
      #
      #     unless values.all? {|value| NAME_OPTIONS.include?(value) }
      #       raise ArgumentError, "invalid value for name: #{values.inspect}"
      #     end
      #
      #     @name = values
      #   end
      #   public :name=
      #
      # Notice options is set as a constant on the receiver class.
      def define_default_writer(receiver_class, caster=nil)
        options = define_default_options_constant(receiver_class)

        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(values)
            unless values.kind_of?(Array)
              raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
            end

            values.collect! {|value| #{caster}(value) }

            unless values.all? {|value| #{options}.include?(value) }
              raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
            end

            @#{name} = values
          end
          public :#{name}=
        }, __FILE__, line
      end
    end
  end
end