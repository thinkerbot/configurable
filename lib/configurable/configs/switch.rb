require 'configurable/configs/flag'

module Configurable
  module Configs
    class Switch < Flag
      match TrueClass
    end
  end
end