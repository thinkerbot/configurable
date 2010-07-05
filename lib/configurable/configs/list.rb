require 'configurable/config'

module Configurable
  module Configs
    class List < Config
      def define_writer(receiver_class)
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