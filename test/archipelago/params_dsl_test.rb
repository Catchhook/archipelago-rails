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

  class InValidatorAction < Archipelago::Action
    param :role, :string, required: true, in: %w[admin member viewer]

    authorize { true }

    def perform
      props role: role
    end
  end

  class FormatValidatorAction < Archipelago::Action
    param :slug, :string, required: true, format: /\A[a-z0-9-]+\z/

    authorize { true }

    def perform
      props slug: slug
    end
  end

  class MinMaxValidatorAction < Archipelago::Action
    param :age, :integer, required: true, min: 0, max: 150
    param :name, :string, required: true, min: 2, max: 50

    authorize { true }

    def perform
      props age: age, name: name
    end
  end

  class EmptyAsNilAction < Archipelago::Action
    param :nickname, :string, empty_as_nil: true

    authorize { true }

    def perform
      props nickname: nickname
    end
  end

  class TypedArrayAction < Archipelago::Action
    param :tag_ids, :array, required: true, of: :integer

    authorize { true }

    def perform
      props tag_ids: tag_ids
    end
  end

  class CustomValidateAction < Archipelago::Action
    param :code, :string, required: true, validate: ->(value) {
      value.length == 6 ? nil : "must be exactly 6 characters"
    }

    authorize { true }

    def perform
      props code: code
    end
  end

  DummyContext = Struct.new(:user, :request, :params, :session, :stream)

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

  def test_in_validator_accepts_valid_value
    payload = InValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "role" => "admin" }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal "admin", payload[:props][:role]
  end

  def test_in_validator_rejects_invalid_value
    payload = InValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "role" => "superuser" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is not included in the list"], payload[:errors]["role"]
  end

  def test_format_validator_accepts_matching_value
    payload = FormatValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "slug" => "my-slug-123" }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal "my-slug-123", payload[:props][:slug]
  end

  def test_format_validator_rejects_non_matching_value
    payload = FormatValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "slug" => "INVALID SLUG!" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is invalid"], payload[:errors]["slug"]
  end

  def test_min_max_validator_accepts_in_range
    payload = MinMaxValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "age" => "25", "name" => "Alice" }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal 25, payload[:props][:age]
  end

  def test_min_validator_rejects_below_minimum
    payload = MinMaxValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "age" => "-1", "name" => "Alice" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is too small"], payload[:errors]["age"]
  end

  def test_max_validator_rejects_above_maximum
    payload = MinMaxValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "age" => "200", "name" => "Alice" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is too large"], payload[:errors]["age"]
  end

  def test_min_max_on_string_validates_length
    payload = MinMaxValidatorAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "age" => "25", "name" => "A" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is too small"], payload[:errors]["name"]
  end

  def test_empty_as_nil_treats_blank_string_as_nil
    payload = EmptyAsNilAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "nickname" => "   " }
    ).call

    assert_equal "ok", payload[:status]
    assert_nil payload[:props][:nickname]
  end

  def test_empty_as_nil_preserves_non_empty_string
    payload = EmptyAsNilAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "nickname" => "Bob" }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal "Bob", payload[:props][:nickname]
  end

  def test_typed_array_coerces_elements
    payload = TypedArrayAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "tag_ids" => ["1", "2", "3"] }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal [1, 2, 3], payload[:props][:tag_ids]
  end

  def test_typed_array_rejects_invalid_elements
    payload = TypedArrayAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "tag_ids" => ["1", "abc", "3"] }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["is invalid"], payload[:errors]["tag_ids"]
  end

  def test_custom_validate_accepts_valid_value
    payload = CustomValidateAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "code" => "ABC123" }
    ).call

    assert_equal "ok", payload[:status]
    assert_equal "ABC123", payload[:props][:code]
  end

  def test_custom_validate_rejects_invalid_value
    payload = CustomValidateAction.new(
      ctx: DummyContext.new(nil, nil, nil, nil),
      raw_params: { "code" => "SHORT" }
    ).call

    assert_equal "error", payload[:status]
    assert_equal ["must be exactly 6 characters"], payload[:errors]["code"]
  end
end
