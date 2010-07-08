require 'configurable/configs/flag'

module Configurable
  module Configs
    class Switch < Flag
      @pattern = TrueClass
    end
  end
end