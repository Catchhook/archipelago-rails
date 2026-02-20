# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "archipelago-rails"
  spec.version = "0.1.0"
  spec.authors = ["Archipelago"]
  spec.email = ["dev@archipelago.local"]

  spec.summary = "Server-driven React islands for Rails"
  spec.description = "Inertia-style server-driven props for embedded React islands"
  spec.homepage = "https://github.com/robrace/archipelago/tree/main/archipelago-rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["{app,config,lib,test}/**/*", "Rakefile", "README.md", "Appraisals", "LICENSE.txt"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/robrace/archipelago",
    "changelog_uri" => "https://github.com/robrace/archipelago/releases"
  }

  # Runtime dependency for a Rails engine.
  spec.add_dependency "rails", ">= 7.1", "< 9.0"

  spec.add_development_dependency "appraisal", "~> 2.5"
  spec.add_development_dependency "minitest", ">= 5.20", "< 6.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "sqlite3", ">= 1.6", "< 3.0"
end
