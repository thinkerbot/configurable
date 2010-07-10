require 'configurable/config'

module Configurable
  module Configs
    class Integer < Config
      def self.caster
        "Integer"
      end
    end
  end
end