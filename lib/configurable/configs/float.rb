require 'configurable/config'

module Configurable
  module Configs
    class Float < Config
      match ::Float
    end
  end
end