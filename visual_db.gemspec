# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'date'
require 'visual_db/version'

Gem::Specification.new do |spec|
  spec.name          = "visual_db"
  spec.date          = Date.today.to_s
  spec.version       = VisualDb::VERSION
  spec.authors       = ["Jason Willems"]
  spec.email         = ["jason@willems.ca"]
  spec.summary       = "Visual SQL"
  spec.description   = "Browser front-end for navigating and modifying mySQL databases"
  spec.homepage      = "https://github.com/at1as/visual_db"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "sinatra", "~>1.4", ">= 1.4.5"
  spec.add_runtime_dependency "mysql", "~> 2.9", ">= 2.9.1"
  spec.add_runtime_dependency "vegas", "~> 0.1", ">= 0.1.11"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rack-test", "~> 0.6.3"
  spec.add_development_dependency "tilt"
end

