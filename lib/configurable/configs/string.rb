require 'configurable/config'

module Configurable
  module Configs
    class String < Config
      cast_with :cast_string
      match ::String
    end
  end
end