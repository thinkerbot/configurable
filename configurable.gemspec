Gem::Specification.new do |s|
  s.name = "configurable"
  s.version = "0.0.1"
  s.author = "Simon Chiang"
  s.email = "simon.a.chiang@gmail.com"
  s.homepage = "http://rubyforge.org/projects/tap/"
  s.platform = Gem::Platform::RUBY
  s.summary = "configurable"
  s.require_path = "lib"
  s.rubyforge_project = "tap"
  s.has_rdoc = true
  s.add_dependency("lazydoc", ">= 0.2.0")
  s.add_development_dependency("tap", ">= 0.11.1")
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    lib/configurable.rb
    lib/configurable/config.rb
    lib/configurable/config_hash.rb
    lib/configurable/config_parser.rb
    lib/configurable/config_parser/flag.rb
    lib/configurable/config_parser/list.rb
    lib/configurable/config_parser/option.rb
    lib/configurable/config_parser/switch.rb
    lib/configurable/desc.rb
    lib/configurable/validation.rb
    lib/configurable_class.rb
  }
end