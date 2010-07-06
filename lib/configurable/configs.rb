require 'configurable/configs/list'
require 'configurable/configs/list_select'
require 'configurable/configs/nest'

module Configurable
  module Configs
    module_function
    
    def config_class(list, select)
      case
      when list && select then ListSelect
      when list           then List
      when select         then Select
      else Config
      end
    end
  end
end