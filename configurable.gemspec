Gem::Specification.new do |s|
  s.name = "configurable"
  s.version = "0.5.0"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://tap.rubyforge.org/configurable"
  s.platform = Gem::Platform::RUBY
  s.summary = "configurable"
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.has_rdoc = true
  s.rdoc_options.concat %w{--title Configurable --main README --line-numbers --inline-source}
  s.add_dependency("lazydoc", ">= 0.9.0")

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
    lib/configurable/delegate.rb
    lib/configurable/delegate_hash.rb
    lib/configurable/indifferent_access.rb
    lib/configurable/module_methods.rb
    lib/configurable/validation.rb
    lib/configurable/utils.rb
  }
end