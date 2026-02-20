# frozen_string_literal: true

require_relative "../test_helper"

module Islands
  module NotificationDemo
    class Run < Archipelago::Action
      authorize { true }

      def perform
        props message: "ok"
      end
    end

    class InvalidRun < Archipelago::Action
      param :email, :string, required: true
      authorize { true }

      def perform
        props message: "nope"
      end
    end
  end
end

class NotificationsTest < ArchipelagoTestCase
  DummyContext = Struct.new(:user, :request, :params, :session)

  def test_emits_resolve_notification
    payloads = []

    callback = lambda do |_name, _start, _finish, _id, payload|
      payloads << payload
    end

    ActiveSupport::Notifications.subscribed(callback, "archipelago.action.resolve") do
      Archipelago::Resolver.new.resolve(component: "NotificationDemo", operation: "run")
    end

    assert_equal "NotificationDemo", payloads.first[:component]
    assert_equal "run", payloads.first[:operation]
  end

  def test_emits_error_notification_for_validation_failure
    payloads = []

    callback = lambda do |_name, _start, _finish, _id, payload|
      payloads << payload
    end

    ActiveSupport::Notifications.subscribed(callback, "archipelago.action.error") do
      Islands::NotificationDemo::InvalidRun.new(
        ctx: DummyContext.new(nil, nil, nil, nil),
        raw_params: {}
      ).call
    end

    assert_equal "validation", payloads.first[:reason]
  end
end
