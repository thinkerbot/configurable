require 'configurable/config'

module Configurable
  module Configs
    class String < Config
      match ::String
      
      def self.caster
        "#{self}.cast"
      end
      
      def self.cast(input)
        input.to_s
      end
    end
  end
end