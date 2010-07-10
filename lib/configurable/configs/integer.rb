require 'configurable/config'

module Configurable
  module Configs
    class Integer < Config
      match ::Integer
      
      def self.caster
        "Integer"
      end
    end
  end
end