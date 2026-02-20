# frozen_string_literal: true

module Archipelago
  module Broadcasts
    module_function

    def broadcast(stream_name, props:, version: Archipelago.next_version)
      payload = Archipelago::Response.ok(props: props, version: version)
      unless defined?(ActionCable) && ActionCable.respond_to?(:server)
        raise LoadError, "ActionCable is required for streaming broadcasts"
      end

      ActionCable.server.broadcast(stream_name, payload)
      payload
    end
  end
end
