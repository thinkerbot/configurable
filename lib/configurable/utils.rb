require 'configurable/indifferent_access'

autoload(:YAML, 'yaml')

module Configurable
  module Utils
    module_function
    
    # Dumps delegates to target as yaml.  Delegates are output in order, and
    # symbol keys are be stringified if delegates has been extended with
    # IndifferentAccess (this produces a nicer config file).
    #
    #   class DumpExample
    #     include Configurable
    #
    #     config :sym, :value      # a symbol config
    #     config 'str', 'value'    # a string config
    #   end
    #
    #   Utils.dump(DumpExample.configurations, "\n")
    #   # => %q{
    #   # sym: :value
    #   # str: value
    #   # }
    #
    # Dump may be provided with a block to format each (key, delegate) pair;
    # the block results are pushed directly to target, so newlines must be
    # specified manually.
    # 
    #   Utils.dump(DumpExample.configurations, "\n") do |key, delegate|
    #     yaml = {key => delegate.default}.to_yaml[5..-1]
    #     "# #{delegate[:desc]}\n#{yaml}\n"
    #   end
    #   # => %q{
    #   # # a symbol config
    #   # sym: :value
    #   #
    #   # # a string config
    #   # str: value
    #   #
    #   # }
    #
    def dump(delegates, target="")
      unless block_given?
        return dump(delegates, target) do |key, delegate|
          {key => delegate.default}.to_yaml[5..-1]
        end
      end
      
      stringify = delegates.kind_of?(IndifferentAccess)
      delegates.each_pair do |key, delegate|
        key = key.to_s if stringify && key.kind_of?(Symbol)
        target << yield(key, delegate)
      end
      
      target
    end
    
    def dump_file(delegates, path, nested=false, &block)
      
    end
    
    def load(str)
      YAML.load(str)
    end
    
    def load_file(path, nested=false)
    end
  end
end