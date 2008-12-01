module Configurable
  module Utils
    module_function
    
    # Loads the contents of path as YAML.  Returns an empty hash if the path 
    # is empty, does not exist, or is not a file.
    def load(path, recursive=true, symbolize=false)
      base = case
      when path == nil then {}
      when !File.file?(path) then {}
      when File.size(path) == 0 then {}    # is there a faster way to check for empty content?
      else YAML.load_file(path) || {}
      end

      if recursive
        # determine the files/dirs to load recursively
        # and add them to paths by key (ie the base 
        # name of the path, minus any extname)
        paths = {}
        files, dirs = Dir.glob("#{path.chomp(File.extname(path))}/*").partition do |sub_path| 
          File.file?(sub_path)
        end
        
        # directories are added to paths first so they can be
        # overridden by the files (appropriate since the file
        # will recursively load the directory if it exists)
        dirs.each do |dir| 
          paths[File.basename(dir)] = dir
        end
        
        # when adding files, check that no two files map to
        # the same key (ex a.yml, a.yaml).
        files.each do |filepath| 
          key = File.basename(filepath).chomp(File.extname(filepath))
          if existing = paths[key]
            if File.file?(existing)
              confict = [File.basename(paths[key]), File.basename(filepath)].sort
              raise "multiple files load the same key: #{confict.inspect}"
            end
          end
          
          paths[key] = filepath
        end
        
        # recursively load each file and reverse merge
        # the result into the base
        paths.each_pair do |key, recursive_path|
          value = nil
          each_in(base) do |hash|
            unless hash.has_key?(key)
              hash[key] = (value ||= load(recursive_path, recursive, symbolize))
            end
          end
        end
      end
      
      base = each_in(base) do |hash|
        hash.replace(symbolize(hash))
      end if symbolize
      
      base
    end
    
    # Symbolizes String keys of the hash (only) and returns
    # the symbolized hash.
    def symbolize(hash)
      hash.inject({}) do |opts, (key, value)|
        opts[key.kind_of?(String) ? key.to_sym : key] = value
        opts
      end
    end
    
    # Yields each hash in the collection (ie each member of
    # an Array, or the collection if it is a hash).  Returns
    # the collection.
    def each_in(collection) # :yields: hash
      case collection
      when Hash then yield(collection)
      when Array 
        collection.each do |hash|
          yield(hash) if hash.kind_of?(Hash)
        end
      end
      
      collection
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