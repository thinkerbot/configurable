require 'configurable/configs/flag'

module Configurable
  module Configs
    class Switch < Flag
      cast_with :cast_boolean
      match TrueClass
    end
  end
end