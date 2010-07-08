require 'configurable/configs/switch'
require 'configurable/configs/integer'
require 'configurable/configs/float'
require 'configurable/configs/nest'

module Configurable
  module Configs
    DEFAULTS = {
      :flag    => Flag,
      :switch  => Switch,
      :integer => Integer,
      :float   => Float,
      nil      => Config
    }
    
    MAP = {
      FalseClass => :flag,
      TrueClass => :switch,
      ::Integer => :integer,
      ::Float => :float
    }
  end
end
    