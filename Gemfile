#############################################################################
# Dependencies in this Gemfile are managed through the gemspec.  Add/remove
# depenencies there, rather than editing this file ex:
#
#   Gem::Specification.new do |s|
#     ... 
#     s.add_dependency("sinatra")
#     s.add_development_dependency("rack-test")
#   end
#
#############################################################################

project_dir = File.expand_path('..', __FILE__)
gemspec_path = File.expand_path('configurable.gemspec', project_dir)

#
# Setup gemspec dependencies
#

gemspec = eval(File.read(gemspec_path))
gemspec.dependencies.each do |dep|
  group = dep.type == :development ? :development : :default
  gem dep.name, dep.requirement, :group => group
end
gem(gemspec.name, gemspec.version, :path => project_dir)

#
# Setup sources
#

source :gemcutter
path project_dir, :glob => "submodule/*/*.gemspec"
