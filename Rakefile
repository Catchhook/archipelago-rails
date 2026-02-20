# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new("test:core") do |t|
  t.libs << "test"
  t.pattern = "test/archipelago/**/*_test.rb"
end

Rake::TestTask.new("test:rails") do |t|
  t.libs << "test"
  t.pattern = ["test/controllers/**/*_test.rb", "test/generators/**/*_test.rb"]
end

task test: ["test:core", "test:rails"]

task default: :test
