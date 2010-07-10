require 'configurable/config'

module Configurable
  module Configs
    class Flag < Config
      cast_with :cast_boolean
      match FalseClass
    end
  end
end