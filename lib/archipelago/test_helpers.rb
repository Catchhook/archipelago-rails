# frozen_string_literal: true

module Archipelago
  module TestHelpers
    def island_post(component, operation, params = {})
      post "/islands/#{component}/#{operation}", params: params, as: :json
    end

    def parsed_island_response
      JSON.parse(response.body)
    end

    def assert_island_props(key, value)
      body = parsed_island_response
      assert_equal "ok", body["status"]
      assert_equal value, body.fetch("props").fetch(key.to_s)
    end

    def assert_island_redirect(path)
      body = parsed_island_response
      assert_equal "redirect", body["status"]
      assert_equal path, body["location"]
    end

    def assert_island_errors(field)
      body = parsed_island_response
      assert_equal "error", body["status"]
      assert body.fetch("errors").key?(field.to_s)
    end
  end
end
