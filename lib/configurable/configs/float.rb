require 'configurable/config'

module Configurable
  module Configs
    class Float < Config
      match ::Float
      
      def self.caster
        "Float"
      end
    end
  end
end