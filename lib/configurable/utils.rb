require 'configurable/indifferent_access'

autoload(:YAML, 'yaml')

module Configurable
  module Utils
    module_function
    
    DEFAULT_DUMP = lambda do |key, delegate|
      default = delegate.default(false)
      default = default.to_hash if delegate.is_nest?
      {key => default}.to_yaml[5..-1]
    end
    
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
      return dump(delegates, target, &DEFAULT_DUMP) unless block_given?
      
      stringify = delegates.kind_of?(IndifferentAccess)
      delegates.each_pair do |key, delegate|
        key = key.to_s if stringify && key.kind_of?(Symbol)
        target << yield(key, delegate)
      end
      
      target
    end
    
    def dump_file(delegates, path, nested=false, &block)
      return dump_file(delegates, path, nested, &DEFAULT_DUMP) unless block_given?
      
      if nested && !delegates.kind_of?(IndifferentAccess)
        raise "nested dumps are not allowed unless delegates use IndifferentAccess: #{path}"
      end
      
      File.open(path, "w") do |io|
        dump(delegates, io) do |key, delegate|
          if nested && delegate.is_nest?
            dump_file(delegate.default(false).delegates, nest_path(key, path), nested, &block)
            ""
          else
            yield(key, delegate)
          end
        end
      end
    end
    
    def load(str)
      YAML.load(str)
    end
    
    def load_file(path, nested=false)
    end
    
    protected
    
    def nest_path(key, path) # :nodoc:
      ext = File.extname(path)
      dir = path.chomp(ext)
      Dir.mkdir(dir) unless File.exists?(dir)
      
      unless key.kind_of?(String) || key.kind_of?(Symbol)
        raise "nested dump is only allowed for String and Symbol keys"
      end
      
      "#{File.join(dir, key.to_s)}#{ext}"
    end
  end
end