# frozen_string_literal: true

require_relative "../test_helper"

class ChannelTest < ArchipelagoTestCase
  def test_stream_pattern_accepts_safe_names
    assert_match Archipelago::IslandChannel::STREAM_PATTERN, "TeamMembers:1"
    assert_match Archipelago::IslandChannel::STREAM_PATTERN, "teams:abc_123"
  end

  def test_stream_pattern_rejects_unsafe_names
    refute_match Archipelago::IslandChannel::STREAM_PATTERN, "../etc/passwd"
    refute_match Archipelago::IslandChannel::STREAM_PATTERN, "team members"
  end
end
