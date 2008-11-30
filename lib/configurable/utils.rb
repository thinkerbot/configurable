module Configurable
  module Utils
    module_function
    
    # Loads the contents of path as YAML.  Returns an empty hash if the path 
    # is empty, does not exist, or is not a file.
    def load(path, recursive=true)
      base = case
      when path == nil then {}
      when !File.file?(path) then {}
      when File.size(path) == 0 then {}    # is there a faster way to check for empty content?
      else YAML.load_file(path) || {}
      end

      if recursive
        files, dirs = Dir.glob("#{path.chomp(File.extname(path))}/*").partition {|sub_path| File.file?(sub_path)} 

        files.each do |sub_path|
          key = File.basename(sub_path).chomp(File.extname(sub_path))
          
          # don't add if already specified
          value = load(sub_path, true)
          each_in(base) {|hash| hash[key] ||= value}
        end
        
        dirs.each do |sub_path|
          key = File.basename(sub_path)
          value = load(sub_path, true)
          
          # merge result with the existing, or add
          each_in(base) do |hash|
            each_in(hash[key] ||= {}) do |current|
              current.merge!(value)
            end
          end
        end
      end

      base
    end
    
    # Yields each hash in the collection (ie each member of
    # an Array, or the collection if it is a hash).  Raises
    # an error if the collection is not an Array or Hash.
    # Also raises an error if an array collection has
    # non-hash entries.
    def each_in(collection) # :yields: hash
      case collection
      when Hash then yield(collection)
      when Array 
        collection.each do |hash|
          unless hash.kind_of?(Hash)
            raise ArgumentError, "Array contains non-Hash entries: #{collection}"
          end
          
          yield(hash)
        end
      else
        raise ArgumentError, "not an Array or Hash: #{collection}"
      end
    end
    
    def recurse(delegates, nest=[], &block)
      delegates.each_pair do |key, config|
        yield(nest, key, config)
        
        config_hash = config.default(false)
        if config_hash.kind_of?(Configurable::ConfigHash)
          recurse(config_hash.delegates, nest + [key], &block)
        end
      end
    end
    
    def dump(config)
    end 
  end
end