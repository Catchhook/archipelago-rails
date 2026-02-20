# frozen_string_literal: true

require_relative "../test_helper"

class BroadcastsTest < ArchipelagoTestCase
  ServerStub = Struct.new(:broadcasts) do
    def broadcast(stream_name, payload)
      broadcasts << [stream_name, payload]
    end
  end

  def test_broadcasts_ok_payload_with_version
    server = ServerStub.new([])
    original_server_method = ActionCable.method(:server)
    previous_verbose, $VERBOSE = $VERBOSE, nil

    ActionCable.singleton_class.define_method(:server) { server }

    begin
      payload = Archipelago::Broadcasts.broadcast("TeamMembers:1", props: { members: [1] }, version: 10)

      assert_equal "ok", payload[:status]
      assert_equal ["TeamMembers:1", payload], server.broadcasts.first
    ensure
      ActionCable.singleton_class.define_method(:server, original_server_method)
      $VERBOSE = previous_verbose
    end
  end
end
