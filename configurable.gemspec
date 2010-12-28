# -*- encoding: utf-8 -*-
require File.expand_path('../lib/configurable/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'configurable'
  s.version = Configurable::VERSION
  s.author = 'Simon Chiang'
  s.email = 'simon.a.chiang@gmail.com'
  s.homepage = 'http://tap.rubyforge.org/configurable'
  s.platform = Gem::Platform::RUBY
  s.summary = 'configurable'
  s.require_path = 'lib'
  s.rubyforge_project = 'tap'
  s.has_rdoc = true
  s.rdoc_options.concat %w{--main README -S -N --title Configurable}
  
  s.add_dependency('lazydoc', "~> 1.0")
  s.add_dependency('config_parser', "= 0.5.4")
  s.add_development_dependency('bundler', '~> 1.0')

  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    MIT-LICENSE
    README
    History
    doc/Basic\ Syntax
    doc/Command\ Line
    doc/Config\ Types
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
end