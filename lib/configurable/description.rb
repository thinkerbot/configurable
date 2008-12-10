require 'lazydoc/attributes'

module Configurable
  
  # Description is a subclass of Lazydoc::Comment that self-resolves 
  # and returns trailer upon to_s.  These qualities allow Description
  # to serve as a substitute for a String description of configurations.
  class Description < Lazydoc::Comment
    # Self-resolves as necessary and returns the trailer.
    def to_s
      document.resolve unless document == nil || document.resolved
      trailer
    end
  end
end