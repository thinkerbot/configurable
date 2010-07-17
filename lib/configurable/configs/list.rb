module Configurable
  module Configs
    class List < Config
      def define_writer(receiver_class)
        caster = get_caster(receiver_class)
        options = self.options
        ivar = self.ivar
        name = self.name
        nil_value = self.nil_value
        
        receiver_class.send(:define_method, writer) do |values|
          unless values.kind_of?(Array)
            raise ArgumentError, "invalid value for #{name}: #{values.inspect}"
          end
          
          unless nil_value.nil?
            values.collect! {|value| value.nil? ? nil_value : value }
          end
          
          unless caster.nil?
            values.collect! {|value| send(caster, value) }
          end
          
          unless options.nil? || (values - options).empty?
            raise ArgumentError, "invalid value for #{name}: #{values.inspect}"
          end
          
          instance_variable_set(ivar, values)
        end
      end
    end
  end
end