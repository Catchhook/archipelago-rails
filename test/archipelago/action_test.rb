# frozen_string_literal: true

require_relative "../test_helper"
require "active_model"
begin
  require "active_record"
rescue LoadError
  module ActiveRecord
    class RecordInvalid < StandardError
      attr_reader :record

      def initialize(record)
        @record = record
        super("Record invalid")
      end
    end
  end
end

class ActionTest < ArchipelagoTestCase
  DummyContext = Struct.new(:user, :request, :params, :session)

  class ForbiddenAction < Archipelago::Action
    authorize { false }

    def perform
      props ok: true
    end
  end

  class MissingAuthorizationAction < Archipelago::Action
    def perform
      props ok: true
    end
  end

  class RedirectAction < Archipelago::Action
    authorize { true }

    def perform
      redirect_to "https://evil.test/redirect"
    end
  end

  class BroadcastAction < Archipelago::Action
    authorize { true }

    def perform
      props members: [1, 2]
    end
  end

  class ValidRedirectAction < Archipelago::Action
    authorize { true }

    def perform
      redirect_to "/teams/1"
    end
  end

  class RecordModel
    include ActiveModel::Model

    attr_accessor :email

    validates :email, presence: true
  end

  class RecordInvalidAction < Archipelago::Action
    authorize { true }

    def perform
      model = RecordModel.new(email: nil)
      model.valid?
      raise ActiveRecord::RecordInvalid.new(model)
    end
  end

  def test_authorization_failure_returns_forbidden
    payload = ForbiddenAction.new(ctx: DummyContext.new(nil, nil, nil, nil), raw_params: {}).call

    assert_equal({ status: "forbidden" }, payload)
  end

  def test_missing_authorization_raises_when_required
    Archipelago.configure { |config| config.authorize_by_default = true }

    assert_raises(Archipelago::MissingAuthorization) do
      MissingAuthorizationAction.new(ctx: DummyContext.new(nil, nil, nil, nil), raw_params: {}).call
    end
  end

  def test_invalid_redirect_raises
    assert_raises(Archipelago::InvalidRedirect) do
      RedirectAction.new(ctx: DummyContext.new(nil, nil, nil, nil), raw_params: {}).call
    end
  end

  def test_relative_redirect_is_allowed
    payload = ValidRedirectAction.new(ctx: DummyContext.new(nil, nil, nil, nil), raw_params: {}).call

    assert_equal "redirect", payload[:status]
    assert_equal "/teams/1", payload[:location]
  end

  def test_broadcasts_when_stream_param_present
    captured = nil
    original_broadcast = Archipelago.method(:broadcast)
    previous_verbose, $VERBOSE = $VERBOSE, nil

    Archipelago.singleton_class.define_method(:broadcast) do |stream_name, props:, version:|
      captured = [stream_name, props, version]
    end

    begin
      BroadcastAction.new(
        ctx: DummyContext.new(nil, nil, nil, nil),
        raw_params: { __stream: "TeamMembers:1" }
      ).call
    ensure
      Archipelago.singleton_class.define_method(:broadcast, original_broadcast)
      $VERBOSE = previous_verbose
    end

    assert_equal "TeamMembers:1", captured[0]
    assert_equal({ members: [1, 2] }, captured[1])
    assert_kind_of Integer, captured[2]
  end

  def test_maps_record_invalid_errors
    payload = RecordInvalidAction.new(ctx: DummyContext.new(nil, nil, nil, nil), raw_params: {}).call

    assert_equal "error", payload[:status]
    assert_equal ["Email can't be blank"], payload[:errors]["email"]
  end
end
