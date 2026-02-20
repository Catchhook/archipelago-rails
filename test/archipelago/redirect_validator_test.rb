# frozen_string_literal: true

require_relative "../test_helper"

class RedirectValidatorTest < ArchipelagoTestCase
  def test_accepts_relative_path
    validator = Archipelago::Security::RedirectValidator.new

    assert_equal "/teams/1", validator.validate!("/teams/1")
  end

  def test_rejects_unlisted_absolute_host
    validator = Archipelago::Security::RedirectValidator.new

    assert_raises(Archipelago::InvalidRedirect) do
      validator.validate!("https://example.com/path")
    end
  end

  def test_allows_allowlisted_absolute_host
    config = Archipelago::Configuration.new
    config.allowed_redirect_hosts = ["app.example.com"]

    validator = Archipelago::Security::RedirectValidator.new(configuration: config)

    assert_equal "https://app.example.com/path", validator.validate!("https://app.example.com/path")
  end
end
