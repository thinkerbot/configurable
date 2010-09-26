module Configurable
  module Configs
    class Select < Config
      
      attr_reader :options
      
      def initialize(name, default=nil, reader=nil, writer=nil, attrs={})
        super
        @options = attrs[:options] || []
      end
      
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
      
      def define_default_options_constant(receiver_class)
        const_name = "#{name}_OPTIONS".upcase
        receiver_class.const_set(const_name, options)
        const_name
      end
    end
  end
end