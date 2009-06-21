require 'configurable/class_methods'

module Configurable
  module ModuleMethods
    
    # Extends including classes with Configurable::ClassMethods
    def included(mod)
      mod.extend ClassMethods
      mod.extend ModuleMethods unless mod.kind_of?(Class)
      
      # Normally source_file is set when a class is extended by Lazydoc::Attributes.
      # In this case, Attributes is *included* via ClassMethods (extend is not used).
      # As a result, source_file needs to be set here.
      unless mod.instance_variable_defined?(:@source_file)
        caller[1] =~ Lazydoc::CALLER_REGEXP
        mod.instance_variable_set(:@source_file, File.expand_path($1)) 
      end
      
      unless mod.instance_variable_defined?(:@configurations)
        mod.send(:initialize_configurations).extend(IndifferentAccess)
      end
      
      # add module configurations      
      configurations.each_pair do |key, config| 
        mod.configurations[key] = config.dup
      end unless self == Configurable
      
      super
    end
  end
  
  extend ModuleMethods
end