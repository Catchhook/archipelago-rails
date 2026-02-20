# frozen_string_literal: true

require_relative "../test_helper"
require "rails/all"
require "action_dispatch/testing/integration"

unless defined?(ArchipelagoDummyApp)
  class ArchipelagoDummyApp < Rails::Application
    config.root = File.expand_path("../../", __dir__)
    config.eager_load = false
    config.secret_key_base = "test-key"
    config.hosts << "www.example.com"

    routes.append do
      mount Archipelago::Engine => "/islands"
    end
  end

  ArchipelagoDummyApp.initialize!
end

module Islands
  module TeamMembers
    class AddMember < Archipelago::Action
      authorize { true }

      def perform
        props members: [{ id: 1, email: "person@example.com" }]
      end
    end

    class Forbid < Archipelago::Action
      authorize { false }

      def perform
        props blocked: false
      end
    end

    class DebugMeta < Archipelago::Action
      param :team_id, :integer, required: true
      param :email, :string, strip: true, downcase: true, default: "fallback@example.com"
      param :tags, :array, default: -> { [] }

      authorize { true }

      def perform
        props ok: true
      end
    end
  end
end

class IslandsControllerTest < ActionDispatch::IntegrationTest
  def setup
    super
    Archipelago.reset_configuration!
    Archipelago.registry.clear!
  end

  def test_success_response_contract
    post "/islands/TeamMembers/add_member", params: { email: "person@example.com" }, as: :json

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "ok", body["status"]
    assert_equal "person@example.com", body.fetch("props").fetch("members").first.fetch("email")
  end

  def test_forbidden_response_contract
    post "/islands/TeamMembers/forbid", params: {}, as: :json

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "forbidden", body["status"]
  end

  def test_resolution_failure_is_404
    post "/islands/Unknown/add_member", params: {}, as: :json

    assert_response :not_found
  end

  def test_debug_payload_includes_param_metadata_for_registry_actions
    Archipelago.map "TeamMembers#debug_meta" => Islands::TeamMembers::DebugMeta

    get "/islands/__debug"

    assert_response :ok
    body = JSON.parse(response.body)

    entry = body.fetch("registry_actions").find do |candidate|
      candidate["component"] == "TeamMembers" && candidate["operation"] == "debug_meta"
    end

    refute_nil entry
    assert_equal "Islands::TeamMembers::DebugMeta", entry["handler"]

    team_id = entry.fetch("params").find { |param| param["name"] == "team_id" }
    assert_equal "integer", team_id["type"]
    assert_equal true, team_id["required"]
    assert_equal({ "provided" => false }, team_id["default"])

    email = entry.fetch("params").find { |param| param["name"] == "email" }
    assert_equal "string", email["type"]
    assert_equal({ "provided" => true, "value" => "fallback@example.com" }, email["default"])
    assert_equal(
      { "strip" => true, "downcase" => true, "upcase" => false },
      email["transforms"]
    )

    tags = entry.fetch("params").find { |param| param["name"] == "tags" }
    assert_equal({ "provided" => true, "kind" => "callable" }, tags["default"])
  end
end
