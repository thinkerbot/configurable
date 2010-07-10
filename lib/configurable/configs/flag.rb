require 'configurable/config'

module Configurable
  module Configs
    class Flag < Config
      match FalseClass
    end
  end
end