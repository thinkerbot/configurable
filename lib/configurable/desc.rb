module Configurable
  class Desc < Lazydoc::Comment
    attr_accessor :summary
    
    def to_s
      summary
    end
    
    def resolve(lines)
      super
      
      # currently removes the :no_default: document modifier
      # which is used during generation of TDoc
      self.summary = subject.to_s =~ /#\s*(:no_default:)?\s*(.*)$/ ? $2.strip : ""
    end
  end
end