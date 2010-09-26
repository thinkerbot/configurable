module Configurable
  module Configs
    class ListSelect < Select
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