module Configurable
  
  # Desc is a special type of Lazydoc::Comment which pulls a summary
  # out of the subject line.
  class Desc < Lazydoc::Comment
    SUMMARY_REGEXP = /#\s*(:no_default:)?\s*(.*)$/
    
    # The summary comment for the configuration.
    attr_accessor :summary
    
    # Returns the summary (not the subject as usual)
    def to_s
      summary
    end
    
    # Overrides resolve to pull out the summary.  Resolve will
    # removes the :no_default: document modifier used by TDoc.
    def resolve(lines)
      super
      self.summary = subject.to_s =~ SUMMARY_REGEXP ? $2.strip : ""
    end
  end
end