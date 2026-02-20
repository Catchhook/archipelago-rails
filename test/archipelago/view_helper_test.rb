# frozen_string_literal: true

require_relative "../test_helper"

class ViewHelperTest < ArchipelagoTestCase
  ViewContext = Class.new do
    include ActionView::Helpers::TagHelper
    include Archipelago::ViewHelper
  end

  def test_renders_island_div_with_data_attributes
    html = ViewContext.new.archipelago_island(
      "TeamMembers",
      props: { members: [{ id: 1 }] },
      params: { team_id: 9 },
      instance: "team_9_members",
      stream: true,
      class: "island"
    )

    assert_includes html, "data-island=\"true\""
    assert_includes html, "data-component=\"TeamMembers\""
    assert_includes html, "data-stream=\"TeamMembers:team_9_members\""
    assert_includes html, "class=\"island\""
  end

  def test_requires_instance_when_stream_true
    assert_raises(ArgumentError) do
      ViewContext.new.archipelago_island("TeamMembers", props: {}, params: {}, stream: true)
    end
  end
end
