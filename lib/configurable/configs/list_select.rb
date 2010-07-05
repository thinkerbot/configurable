require 'configurable/configs/select'

module Configurable
  module Configs
    class ListSelect < Select
      def define_writer(receiver_class)
        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(values)
            unless values.kind_of?(Array)
              raise ArgumentError, "invalid value for #{name}: \#{values.inspect}"
            end

            values.collect! {|value| #{caster}(value) }

            unless values.all? {|value| #{options_const_name}.include?(value) }
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