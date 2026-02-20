# frozen_string_literal: true

require_relative "../test_helper"

class ParamsDSLTest < ArchipelagoTestCase
  class ParamAction < Archipelago::Action
    param :team_id, :integer, required: true
    param :email, :string, required: true, strip: true, downcase: true
    param :notify, :boolean, default: false

    authorize { true }

    def perform
      props team_id: team_id, email: email, notify: notify
    end
  end

  DummyContext = Struct.new(:user, :request, :params, :session)

  def test_coerces_and_transforms_params
    payload = ParamAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "team_id" => "10", "email" => "  USER@EXAMPLE.COM " }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal 10, payload[:props][:team_id]
    assert_equal "user@example.com", payload[:props][:email]
    assert_equal false, payload[:props][:notify]
  end

  def test_reports_required_errors
    payload = ParamAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "team_id" => "10" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is required"], payload[:errors]["email"]
  end

  def test_reports_coercion_errors
    payload = ParamAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "team_id" => "x", "email" => "a@b.c" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is invalid"], payload[:errors]["team_id"]
  end
end
