$:.unshift File.expand_path('../submodule/lazydoc/lib', __FILE__)
$:.unshift File.expand_path('../submodule/config_parser/lib', __FILE__)
$:.unshift File.expand_path('../lib', __FILE__)

require 'lazydoc/version'
require 'config_parser/version'
require 'configurable/version'

$:.shift
$:.shift
$:.shift

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
  
  s.add_dependency('lazydoc', "~> #{Lazydoc::VERSION}")
  s.add_dependency('config_parser', "~> #{ConfigParser::VERSION}")

  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    MIT-LICENSE
    README
    History
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    lib/cdoc.rb
    lib/cdoc/cdoc_html_generator.rb
    lib/cdoc/cdoc_html_template.rb
    lib/config_parser.rb
    lib/config_parser/option.rb
    lib/config_parser/switch.rb
    lib/config_parser/utils.rb
    lib/configurable.rb
    lib/configurable/class_methods.rb
    lib/configurable/config.rb
    lib/configurable/config_hash.rb
    lib/configurable/indifferent_access.rb
    lib/configurable/module_methods.rb
    lib/configurable/nest_config.rb
    lib/configurable/ordered_hash_patch.rb
    lib/configurable/utils.rb
    lib/configurable/validation.rb
    lib/configurable/version.rb
  }
end