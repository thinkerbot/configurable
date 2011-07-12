# -*- encoding: utf-8 -*-
$:.unshift File.expand_path('../lib', __FILE__)
require 'configurable/version'
$:.shift

Gem::Specification.new do |s|
  s.name    = 'configurable'
  s.version = Configurable::VERSION
  s.authors = ['Simon Chiang']
  s.email   = ['simon.a.chiang@gmail.com']
  s.homepage = 'http://github.com/thinkerbot/configurable'
  s.summary = 'configurable'
  s.description = %w{
    Configurable adds methods to declare class configurations. Configurations are
    inheritable, delegate to methods, and have hash-like access. Configurable
    constructs configs such that they easily map to config files, web forms, and
    the command line.
  }.join(' ')

  s.has_rdoc = true
  s.rdoc_options.concat %w{--main README.rdoc -S -N --title Configurable}

  # add dependencies
  s.add_dependency('lazydoc', '~> 1.0')
  s.add_dependency('config_parser', '~> 0.5.4')
  s.add_development_dependency('bundler', '~> 1.0')

  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    MIT-LICENSE
    README.rdoc
    History.rdoc
    Usage/Command\ Line.rdoc
    Usage/Config\ Syntax.rdoc
    Usage/Config\ Types.rdoc
  }

  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    lib/configurable.rb
    lib/configurable/class_methods.rb
    lib/configurable/config_classes.rb
    lib/configurable/config_classes/list_config.rb
    lib/configurable/config_classes/nest_config.rb
    lib/configurable/config_classes/scalar_config.rb
    lib/configurable/config_hash.rb
    lib/configurable/config_types.rb
    lib/configurable/config_types/boolean_type.rb
    lib/configurable/config_types/float_type.rb
    lib/configurable/config_types/integer_type.rb
    lib/configurable/config_types/nest_type.rb
    lib/configurable/config_types/object_type.rb
    lib/configurable/config_types/string_type.rb
    lib/configurable/conversions.rb
    lib/configurable/module_methods.rb
    lib/configurable/version.rb
  }

  s.require_paths = ['lib']
end