module Configurable
  module Configs
    class ListSelect < Select
      def define_writer(receiver_class, caster=nil)
        options = define_options_constant(receiver_class)

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
      
      def parse(switch, value, argv=[], config={})
        split = ',' # attributes[:split]
        n = nil # attributes[:n]

        array = (config[name] ||= [])
        array.concat(split ? value.split(split) : [value])
        if n && array.length > n
          raise "too many assignments: #{name.inspect}"
        end
        
        array
      end
    end
  end
end