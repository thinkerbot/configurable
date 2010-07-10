require 'configurable/config'

module Configurable
  module Configs
    class Integer < Config
      cast_with :Integer
      match ::Integer
    end
  end
end