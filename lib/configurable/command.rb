require 'configurable'

module Configurable
  class Command
    class << self
      def name
        @name ||= File.basename(
          to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
        )
      end
    end
    
    extend Lazydoc::Attributes
    include Configurable
    
    lazy_attr :desc
    lazy_attr :args, :process
    lazy_register :process, Lazydoc::Arguments
    
    def initialize(config={})
      initialize_config(config)
    end
    
    def call(argv=[])
      process(*argv)
    end
    
    def process(*args)
      raise NotImplementedError
    end
  end
end