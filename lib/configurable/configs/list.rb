module Configurable
  module Configs
    
    # Represents a list style config where the input is expected to be an
    # Array.  The default writer will enforce this constraint.
    class List < Config
      
      # Defines the default writer method on receiver_class, using the caster
      # to cast each input before setting the config value. The caster should
      # be a method name as this is the added code:
      #
      #   def name=(values)
      #     unless values.kind_of?(Array)
      #       raise ArgumentError, "invalid value for name: #{values.inspect}"
      #     end
      #
      #     values.collect! {|value| caster(value) }
      #     @name = values
      #   end
      #   public :name=
      #
      def define_default_writer(receiver_class, caster=nil)
        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(values)
            unless values.kind_of?(Array)
              raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
            end

            values.collect! {|value| #{caster}(value) }
            @#{name} = values
          end
          public :#{name}=
        }, __FILE__, line
      end
    end
  end
end