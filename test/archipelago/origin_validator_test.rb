# frozen_string_literal: true

require_relative "../test_helper"

class OriginValidatorTest < ArchipelagoTestCase
  RequestStub = Struct.new(:headers, :protocol, :host, :port)

  def test_skips_when_strict_mode_disabled
    config = Archipelago::Configuration.new
    config.strict_origin_check = false

    request = RequestStub.new({ "Origin" => "https://example.com" }, "https://", "example.com", 443)

    assert Archipelago::Security::OriginValidator.new(request, configuration: config).validate!
  end

  def test_allows_matching_origin
    config = Archipelago::Configuration.new
    config.strict_origin_check = true

    request = RequestStub.new({ "Origin" => "https://example.com" }, "https://", "example.com", 443)

    assert Archipelago::Security::OriginValidator.new(request, configuration: config).validate!
  end

  def test_rejects_mismatched_origin
    config = Archipelago::Configuration.new
    config.strict_origin_check = true

    request = RequestStub.new({ "Origin" => "https://attacker.test" }, "https://", "example.com", 443)

    assert_raises(Archipelago::InvalidOrigin) do
      Archipelago::Security::OriginValidator.new(request, configuration: config).validate!
    end
  end
end
