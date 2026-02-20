# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] ||= "test"

require "minitest/autorun"
require "active_support"
require "active_support/testing/time_helpers"
require "action_view"
begin
  require "action_controller/template_assertions"
rescue LoadError
  # Loaded in full Rails app contexts.
end
begin
  require "action_cable/engine"
rescue LoadError
  # Streaming tests require actioncable; core tests can still run without it.
end
require "archipelago"

if defined?(ActionController::Base)
  ActionController::Base.allow_forgery_protection = false
end

class ArchipelagoTestCase < Minitest::Test
  include ActiveSupport::Testing::TimeHelpers

  def setup
    super
    Archipelago.reset_configuration!
    Archipelago.registry.clear!
  end
end
