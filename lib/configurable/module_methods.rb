require 'lazydoc'
require 'configurable/class_methods'

module Configurable
  module ModuleMethods
    module_function
    
    # Extends including classes with Configurable::ClassMethods
    def included(base)
      base.extend ClassMethods
      base.extend Lazydoc::Attributes
      base.extend ModuleMethods unless base.kind_of?(Class)
      
      ClassMethods.initialize(base)
      super
    end
  end
  
  extend ModuleMethods
end