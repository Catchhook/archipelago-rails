# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"
require "active_support/notifications"
require "json"
require "uri"

module Archipelago
  class Error < StandardError; end
  class Forbidden < Error; end
  class ResolutionError < Error; end
  class InvalidOrigin < Error; end
  class InvalidRedirect < Error; end
  class MissingAuthorization < Error; end

  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def registry
      @registry ||= Registry.new
    end

    def map(mapping)
      mapping.each { |key, value| registry.map(key, value) }
    end

    def next_version
      configuration.version_source.call
    end

    def broadcast(stream_name, props:, version: next_version)
      Broadcasts.broadcast(stream_name, props: props, version: version)
    end

    def instrument(event, payload = {}, &block)
      ActiveSupport::Notifications.instrument(event, payload, &block)
    end
  end
end

require "archipelago/configuration"
require "archipelago/registry"
require "archipelago/response"
require "archipelago/params_dsl"
require "archipelago/context"
require "archipelago/security/origin_validator"
require "archipelago/security/redirect_validator"
require "archipelago/action"
require "archipelago/resolver"
require "archipelago/broadcasts"
require "archipelago/channel"
require "archipelago/view_helper"
require "archipelago/test_helpers"
begin
  require "archipelago/engine"
rescue LoadError, NameError
  # Engine support requires railties and loads when running inside Rails.
end
