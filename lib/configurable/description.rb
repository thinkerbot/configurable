require 'lazydoc/attributes'

module Configurable
  
  # Description is a subclass of {Comment}[http://tap.rubyforge.org/lazydoc/classes/Lazydoc/Comment.html] 
  # that self-resolves and returns trailer upon to_s.  Configurable registers
  # config declarations using Description unless a description is provided
  # manually.  As a result, the trailer comment on declarations is available
  # for use by ConfigParser to construct help strings.
  class Description < Lazydoc::Comment
    
    # Self-resolves as necessary and returns the trailer.
    def to_s
      document.resolve unless document == nil || document.resolved
      trailer
    end
  end
end