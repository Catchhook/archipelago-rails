# frozen_string_literal: true

module Archipelago
  module Security
    class RedirectValidator
      def initialize(configuration: Archipelago.configuration)
        @configuration = configuration
      end

      def validate!(location)
        return location if relative_path?(location)

        uri = URI.parse(location)
        unless uri.is_a?(URI::HTTP) && @configuration.allowed_redirect_hosts.include?(uri.host)
          raise Archipelago::InvalidRedirect, "Unsafe redirect host"
        end

        location
      rescue URI::InvalidURIError
        raise Archipelago::InvalidRedirect, "Invalid redirect URI"
      end

      private

      def relative_path?(location)
        location.start_with?("/") && !location.start_with?("//")
      end
    end
  end
end
