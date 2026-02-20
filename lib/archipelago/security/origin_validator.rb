# frozen_string_literal: true

module Archipelago
  module Security
    class OriginValidator
      def initialize(request, configuration: Archipelago.configuration)
        @request = request
        @configuration = configuration
      end

      def validate!
        return true unless @configuration.strict_origin_check

        origin = @request.headers["Origin"]
        return true if origin.nil? || origin.empty?

        uri = URI.parse(origin)
        expected_scheme = @request.protocol.delete_suffix("://")

        valid = uri.scheme == expected_scheme &&
          uri.host == @request.host &&
          uri.port == @request.port

        raise Archipelago::InvalidOrigin, "Origin mismatch" unless valid

        true
      rescue URI::InvalidURIError
        raise Archipelago::InvalidOrigin, "Invalid origin URI"
      end
    end
  end
end
