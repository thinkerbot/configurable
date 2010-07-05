require 'configurable/config'

module Configurable
  module Configs
    class Select < Config
      
      # The constant name of an an optional array of select options.
      attr_reader :options_const_name
      
      def initialize(name, default=nil, options={})
        super
        @options_const_name = options[:options_const_name] or raise "no options constant specified: #{options.inspect}"
      end
      
      def define_writer(receiver_class)
        line = __LINE__ + 1
        receiver_class.class_eval %Q{
          def #{name}=(value)
            value = #{caster}(value)
            unless #{options_const_name}.include?(value)
              raise ArgumentError, "invalid value for #{name}: \#{value.inspect}"
            end
            @#{name} = value
          end
          public :#{name}=
        }, __FILE__, line
      end
    end
  end
end