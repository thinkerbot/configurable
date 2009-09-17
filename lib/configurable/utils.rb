module Configurable
  
  # Utility methods to dump and load configurations, particularly nested
  # configurations.
  module Utils
    module_function
    
    default_dump_block = lambda do |key, delegate|
      # note: this causes order to be lost...
      YAML.dump({key => delegate.default})[5..-1]
    end
    
    # A block performing the default YAML dump.
    DEFAULT_DUMP = default_dump_block
    
    default_load_block = lambda do |base, key, value|
      base[key] ||= value
    end
    
    # A block performing the default load.
    DEFAULT_LOAD = default_load_block
    
    # Dumps delegates to target as yaml.  Delegates are output in order, and
    # symbol keys are be stringified if delegates has been extended with
    # IndifferentAccess (this produces a nicer config file).
    #
    #   class DumpExample
    #     include Configurable
    #
    #     config :sym, :value      # a symbol config
    #     config 'str', 'value'    # a string config
    #   end
    #
    #   Utils.dump(DumpExample.configurations, "\n")
    #   # => %q{
    #   # sym: :value
    #   # str: value
    #   # }
    #
    # Dump may be provided with a block to format each (key, delegate) pair;
    # the block results are pushed directly to target, so newlines must be
    # specified manually.
    # 
    #   Utils.dump(DumpExample.configurations, "\n") do |key, delegate|
    #     yaml = YAML.dump({key => delegate.default})[5..-1]
    #     "# #{delegate[:desc]}\n#{yaml}\n"
    #   end
    #   # => %q{
    #   # # a symbol config
    #   # sym: :value
    #   #
    #   # # a string config
    #   # str: value
    #   #
    #   # }
    #
    def dump(delegates, target="")
      return dump(delegates, target, &DEFAULT_DUMP) unless block_given?
      
      stringify = delegates.kind_of?(IndifferentAccess)
      delegates.each_pair do |key, delegate|
        key = key.to_s if stringify && key.kind_of?(Symbol)
        target << yield(key, delegate)
      end
      
      target
    end
    
    # Dumps the delegates to the specified file.  If recurse is true, nested
    # configurations are each dumped to their own file, based on the nesting
    # key.  For instance if you nested a in b:
    #
    #   a_configs = {
    #     'key' => Delegate.new(:r, :w, 'a default')}
    #   b_configs = {
    #     'key' => Delegate.new(:r, :w, 'b default')}
    #     'a' => Delegate.new(:r, :w, DelegateHash.new(a_configs))}}
    #
    #   Utils.dump_file(b_configs, 'b.yml')
    #   File.read('b.yml')         # => "key: b default"
    #   File.read('b/a.yml')       # => "key: a default"
    #
    # In this way, each nested config gets it's own file.  The load_file method
    # can recursively load configurations from this file structure. When recurse
    # is false, all configs are dumped to a single file.
    #
    # dump_file uses a method that collects all dumps in a preview array before
    # dumping, so that the dump results can be redirected other places than the
    # file system.  If preview is set to false, no files will be created.  The
    # preview dumps are always returned by dump_file.
    #
    # ==== Note
    # For load_file to correctly load a recursive dump, all delegate hashes
    # must use String keys.  Symbol keys are allowed if the delegate hashes use
    # IndifferentAccess; all other keys will not load properly.  By default 
    # Configurable is set up to satisfy these conditions.
    #
    # 1.8 Bug: Currently dump_file with recurse=false will cause order to be
    # lost in nested configs. See http://bahuvrihi.lighthouseapp.com/projects/21202-configurable/tickets/8
    def dump_file(delegates, path, recurse=false, preview=false, &block)
      return dump_file(delegates, path, recurse, preview, &DEFAULT_DUMP) unless block_given?
      
      current = ""
      dumps = [[path, current]]
      
      dump(delegates, current) do |key, delegate|
        if recurse && delegate.kind_of?(NestDelegate)
          dumps.concat(dump_file(delegate.nest_class.configurations, recursive_path(key, path), true, true, &block))
          ""
        else
          yield(key, delegate)
        end
      end
      
      dumps.each do |dump_path, content|
        dir = File.dirname(dump_path)
        Dir.mkdir(dir) unless File.exists?(dir)
        File.open(dump_path, "w") do |io|
          io << content
        end 
      end unless preview
      
      dumps
    end
    
    # Loads the string as YAML.
    def load(str)
      YAML.load(str)
    end
    
    # Loads the file contents as YAML.  If recurse is true, a hash will be
    # recursively loaded.  A block may be provided to set recursively loaded
    # values in the hash loaded from the path.
    def load_file(path, recurse=false, &block)
      return load_file(path, recurse, &DEFAULT_LOAD) if recurse && !block_given?
      base = File.file?(path) ? (YAML.load_file(path) || {}) : {}
      
      if recurse
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
          value = load_file(recursive_path, true, &block)
          yield(base, key, value)
        end
      end

      base
    end
    
    # A helper to create and prepare a recursive dump path.
    def recursive_path(key, path)
      ext = File.extname(path)
      dir = path.chomp(ext)
      
      "#{File.join(dir, key.to_s)}#{ext}"
    end
  end
end