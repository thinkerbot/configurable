module Configurable
  
  # Beginning with ruby 1.9, Hash tracks the order of insertion and methods
  # like each_pair return pairs in order.  Configurable leverages this feature
  # to keep configurations in order for the command line documentation produced
  # by ConfigParser.
  #
  # Pre-1.9 ruby implementations require a patched Hash that tracks insertion
  # order.  This very thin subclass of hash does that for ASET insertions and
  # each_pair.  OrderedHashPatches are used as the configurations object in 
  # Configurable classes for pre-1.9 ruby implementations and for nothing else.
  #
  # OrderedHashPatch is only loaded for pre-1.9 ruby implementations.
  class OrderedHashPatch < Hash
    def initialize
      super
      @insertion_order = []
    end
    
    # ASET insertion, tracking insertion order.
    def []=(key, value)
      @insertion_order << key unless @insertion_order.include?(key)
      super
    end
    
    # Keys, sorted into insertion order
    def keys
      super.sort_by do |key|
        @insertion_order.index(key) || length
      end
    end
    
    # Yields each key-value pair to the block in insertion order.
    def each_pair
      keys.each do |key|
        yield(key, fetch(key))
      end
    end
    
    # Merges another into self in a way that preserves insertion order.
    def merge!(another)
      another.each_pair do |key, value|
        self[key] = value
      end
    end
    
    # Ensures the insertion order of duplicates is separate from parents.
    def initialize_copy(orig)
      super
      @insertion_order = orig.instance_variable_get(:@insertion_order).dup
    end
    
    # Overridden to load an array of [key, value] pairs in order (see to_yaml).
    # The default behavior for loading from a hash of key-value pairs is
    # preserved, but the insertion order will not be preserved.
    def yaml_initialize( tag, val )
      @insertion_order ||= []
     
      if Array === val
        val.each do |k, v|
          self[k] = v
        end
      else
        super
      end
    end
    
    # Overridden to preserve insertion order by serializing self as an array
    # of [key, value] pairs.
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.seq( taguri, to_yaml_style ) do |seq|
          each_pair do |key, value|
            seq.add( [key, value] )
          end
        end
      end
    end
  end
  
  module ClassMethods
    remove_const(:CONFIGURATIONS_CLASS)
    CONFIGURATIONS_CLASS = OrderedHashPatch
  end
end