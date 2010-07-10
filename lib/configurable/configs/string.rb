require 'configurable/config'

module Configurable
  module Configs
    class String < Config
      match ::String
    end
  end
end