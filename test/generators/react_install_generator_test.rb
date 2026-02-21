# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/archipelago/install/react_generator"
require "json"

class ReactInstallGeneratorTest < Rails::Generators::TestCase
  tests Archipelago::Generators::Install::ReactGenerator
  destination File.expand_path("../../tmp", __dir__)

  setup :prepare_destination

  def setup
    super
    FileUtils.mkdir_p(File.join(destination_root, "app/javascript"))
    File.write(File.join(destination_root, "app/javascript/application.js"), "// entry\n")
    File.write(File.join(destination_root, "Gemfile"), "gem \"jsbundling-rails\"\n")
    File.write(
      File.join(destination_root, "package.json"),
      <<~JSON
        {
          "name": "dummy",
          "scripts": {
            "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds",
            "build:watch": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds --watch"
          }
        }
      JSON
    )
  end

  def test_generates_entry_and_wires_application_import
    run_generator %w[--interactive=false]

    assert_file "app/javascript/archipelago/entry.jsx", /import registry from "\.\/registry\.generated"/
    assert_file "app/javascript/application.js", /import "\.\/archipelago\/entry"/
    assert_file "app/javascript/archipelago/generate_registry.mjs", /registry\.generated\.js/
    assert_file "app/javascript/archipelago/registry.generated.js", /const registry = \{\}/

    package_json = JSON.parse(File.read(File.join(destination_root, "package.json")))
    assert_equal "node app/javascript/archipelago/generate_registry.mjs", package_json.dig("scripts", "archipelago:registry")
    assert_match(/^node app\/javascript\/archipelago\/generate_registry\.mjs && /, package_json.dig("scripts", "build"))
    assert_file ".npmrc", /@archipelago-js:registry=https:\/\/registry\.npmjs\.org/
  end

  def test_generates_typescript_entry_when_requested
    run_generator %w[--interactive=false --typescript=true]

    assert_file "app/javascript/archipelago/entry.tsx", /import registry from "\.\/registry\.generated"/
    assert_file "app/javascript/archipelago/registry.generated.ts", /const registry: IslandRegistry = \{\}/
  end

  def test_auto_detects_typescript_when_tsconfig_present
    File.write(File.join(destination_root, "tsconfig.json"), "{\n}\n")

    run_generator %w[--interactive=false]

    assert_file "app/javascript/archipelago/entry.tsx", /bootArchipelagoIslands/
  end

  def test_can_disable_auto_registry
    run_generator %w[--interactive=false --auto_registry=false]

    assert_file "app/javascript/archipelago/entry.jsx", /const registry = \{/
    refute File.exist?(File.join(destination_root, "app/javascript/archipelago/generate_registry.mjs"))
  end

  def test_does_not_duplicate_scope_registry_when_already_present
    File.write(File.join(destination_root, ".npmrc"), "@archipelago-js:registry=https://registry.npmjs.org\n")

    run_generator %w[--interactive=false]

    npmrc = File.read(File.join(destination_root, ".npmrc"))
    assert_equal 1, npmrc.scan("@archipelago-js:registry=").length
  end
end
