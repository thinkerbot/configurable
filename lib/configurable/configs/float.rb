require 'configurable/config'

module Configurable
  module Configs
    class Float < Config
      cast_with :Float
      match ::Float
    end
  end
end