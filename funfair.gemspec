# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'funfair/version'

Gem::Specification.new do |spec|
  spec.name          = "funfair"
  spec.version       = Funfair::VERSION
  spec.authors       = ["Kliment Mamykin"]
  spec.email         = ["kmamyk@gmail.com"]
  spec.description   = %q{Funfair is an idiomatic wrapper on top of amqp gem implementing common messaging patterns.}
  spec.summary       = %q{Funfair is an idiomatic wrapper on top of amqp gem implementing common messaging patterns.}
  spec.homepage      = "https://github.com/kmamykin/funfair"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'amqp', '~> 1.0'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'rspec', '~> 2.13'
  spec.add_development_dependency 'evented-spec', '~> 0.9'
end
