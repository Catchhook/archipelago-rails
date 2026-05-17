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

  def test_authorize_stream_returns_true_when_no_authorizer_and_not_required
    Archipelago.configure do |config|
      config.stream_authorizer = nil
      config.require_stream_authorization = false
    end

    assert Archipelago.authorize_stream?(connection: nil, stream_name: "test:1")
  end

  def test_authorize_stream_rejects_all_when_required_but_no_authorizer
    Archipelago.configure do |config|
      config.stream_authorizer = nil
      config.require_stream_authorization = true
    end

    refute Archipelago.authorize_stream?(connection: nil, stream_name: "test:1")
  end

  def test_authorize_stream_calls_authorizer_lambda
    called_with = nil
    Archipelago.configure do |config|
      config.stream_authorizer = ->(connection:, stream_name:, params:) {
        called_with = { connection: connection, stream_name: stream_name, params: params }
        stream_name.start_with?("allowed:")
      }
    end

    assert Archipelago.authorize_stream?(connection: :conn, stream_name: "allowed:1", params: { a: 1 })
    assert_equal :conn, called_with[:connection]
    assert_equal "allowed:1", called_with[:stream_name]
    assert_equal({ a: 1 }, called_with[:params])

    refute Archipelago.authorize_stream?(connection: :conn, stream_name: "denied:1")
  end
end
