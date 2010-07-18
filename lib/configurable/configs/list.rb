module Configurable
  module Configs
    class List < Config
      def define_writer(receiver_class, caster=nil)
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
      
      def parse(switch, value, argv=[], config={})
        split = ',' # attributes[:split]
        n = nil # attributes[:n]
        
        value = argv.shift if value.nil?
        
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