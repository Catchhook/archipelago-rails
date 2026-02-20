# frozen_string_literal: true

require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/archipelago/island_generator"

class IslandGeneratorTest < Rails::Generators::TestCase
  tests Archipelago::Generators::IslandGenerator
  destination File.expand_path("../../tmp", __dir__)

  setup :prepare_destination

  def test_generates_action_and_component_files
    run_generator %w[TeamMembers add_member remove_member]

    assert_file "app/islands/team_members/add_member.rb", /class AddMember < Archipelago::Action/
    assert_file "app/islands/team_members/remove_member.rb", /class RemoveMember < Archipelago::Action/
    assert_file "app/javascript/islands/TeamMembers.tsx", /useIslandProps/
  end
end
