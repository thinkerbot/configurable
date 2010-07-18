module Configurable
  module Configs
    class Flag < Config
      def parse(switch, value, argv=[], config={})
        raise "value specified for flag: #{switch}" unless value.nil?
        config[name] = !default
      end
    end
  end
end