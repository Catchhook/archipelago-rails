# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/archipelago/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests Archipelago::Generators::InstallGenerator
  destination File.expand_path("../../tmp", __dir__)

  setup :prepare_destination

  def setup
    super
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
  end

  def test_generates_initializer_and_islands_dir
    run_generator

    assert_file "app/islands"
    assert_file "config/initializers/archipelago.rb"
    assert_file "config/routes.rb", /mount Archipelago::Engine => "\/islands"/
  end
end
