$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'miasma-local/version'
Gem::Specification.new do |s|
  s.name = 'miasma-local'
  s.version = MiasmaLocal::VERSION.version
  s.summary = 'Smoggy local API'
  s.author = 'Chris Roberts'
  s.email = 'code@chrisroberts.org'
  s.homepage = 'https://github.com/miasma-rb/miasma-local'
  s.description = 'Smoggy local API'
  s.license = 'Apache 2.0'
  s.require_path = 'lib'
  s.add_development_dependency 'miasma'
  s.add_runtime_dependency 'mime-types'
  s.files = Dir['lib/**/*'] + %w(miasma-local.gemspec README.md CHANGELOG.md LICENSE)
end
