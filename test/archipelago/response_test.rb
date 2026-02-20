# frozen_string_literal: true

require_relative "../test_helper"

class ResponseTest < ArchipelagoTestCase
  def test_ok_payload
    payload = Archipelago::Response.ok(props: { members: [] }, version: 7)

    assert_equal "ok", payload[:status]
    assert_equal({ members: [] }, payload[:props])
    assert_equal 7, payload[:version]
  end

  def test_redirect_payload
    payload = Archipelago::Response.redirect(location: "/teams/1")

    assert_equal({ status: "redirect", location: "/teams/1" }, payload)
  end

  def test_error_payload
    payload = Archipelago::Response.error(errors: { "email" => ["is invalid"] })

    assert_equal "error", payload[:status]
    assert_equal ["is invalid"], payload[:errors]["email"]
  end

  def test_forbidden_payload
    assert_equal({ status: "forbidden" }, Archipelago::Response.forbidden)
  end
end
