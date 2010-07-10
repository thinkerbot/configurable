require 'configurable/config'

module Configurable
  module Configs
    class Float < Config
      def self.caster
        "Float"
      end
    end
  end
end