# frozen_string_literal: true

module Archipelago
  module Response
    module_function

    def ok(props:, version:)
      {
        status: "ok",
        props: props,
        version: version
      }
    end

    def redirect(location:)
      {
        status: "redirect",
        location: location
      }
    end

    def error(errors:)
      {
        status: "error",
        errors: errors
      }
    end

    def forbidden
      {
        status: "forbidden"
      }
    end
  end
end
