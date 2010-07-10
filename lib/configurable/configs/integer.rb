require 'configurable/config'

module Configurable
  module Configs
    class Integer < Config
      match ::Integer
    end
  end
end