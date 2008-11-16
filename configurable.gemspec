Gem::Specification.new do |s|
  s.name = "configurable"
  s.version = "0.0.1"
  #s.author = "Your Name Here"
  #s.email = "your.email@pubfactory.edu"
  #s.homepage = "http://rubyforge.org/projects/configurable/"
  s.platform = Gem::Platform::RUBY
  s.summary = "configurable"
  s.require_path = "lib"
  s.test_file = "test/tap_test_suite.rb"
  #s.rubyforge_project = "configurable"
  #s.has_rdoc = true
  s.add_dependency("tap", "= 0.11.1")
  
  # list extra rdoc files here.
  s.extra_rdoc_files = %W{
    README
  }
  
  # list the files you want to include here. you can
  # check this manifest using 'rake :print_manifest'
  s.files = %W{
    tap.yml
    test/tap_test_helper.rb
    test/tap_test_suite.rb
  }
end