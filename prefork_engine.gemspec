# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'prefork_engine/version'

Gem::Specification.new do |spec|
  spec.name          = "prefork_engine"
  spec.version       = PreforkEngine::VERSION
  spec.authors       = ["Masahiro Nagano"]
  spec.email         = ["kazeburo@gmail.com"]
  spec.summary       = %q{a simple prefork server framework}
  spec.description   = %q{a simple prefork server framework. ruby port of perl's Parallel::Prefork}
  spec.homepage      = "https://github.com/kazeburo/prefork_engine/"
  spec.license       = "Artistic"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.add_dependency "proc-wait3", "~> 1.7.2"
end
