# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "csv2rdf"
  spec.version       = "0.2"
  spec.authors       = ["JeniT"]
  spec.email         = ["jeni@jenitennison.com"]
  spec.description   = %q{CSV to RDF Converter}
  spec.summary       = %q{CSV to RDF Converter}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rdf"
  spec.add_dependency "csvlint"
  # spec.add_dependency "mime-types"
  # spec.add_dependency "colorize"
  # spec.add_dependency "open_uri_redirections"
  # spec.add_dependency "activesupport"
  # spec.add_dependency "addressable"
  # spec.add_dependency "typhoeus"
  # spec.add_dependency "escape_utils"
  # spec.add_dependency "uri_template"
  # spec.add_dependency "thor"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "cucumber"
  # spec.add_development_dependency "simplecov"
  # spec.add_development_dependency "simplecov-rcov"
  spec.add_development_dependency "spork"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "rspec"
  # spec.add_development_dependency "rspec-pride"
  # spec.add_development_dependency "rspec-expectations"
  spec.add_development_dependency "coveralls"
  spec.add_development_dependency "pry"
  # spec.add_development_dependency "github_changelog_generator"
  # spec.add_development_dependency "aruba"
  spec.add_development_dependency "rdf-turtle"
  spec.add_development_dependency "rdf-isomorphic"
end
