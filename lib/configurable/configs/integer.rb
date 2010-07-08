require 'configurable/config'

module Configurable
  module Configs
    class Integer < Config
      @pattern = Fixnum
      
      def self.caster
        "Integer"
      end
    end
  end
end