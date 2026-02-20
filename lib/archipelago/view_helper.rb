# frozen_string_literal: true

module Archipelago
  module ViewHelper
    def archipelago_island(component, props:, params: {}, instance: nil, stream: nil, **html_options)
      stream_name = resolve_stream_name(component: component, instance: instance, stream: stream)

      data_attributes = {
        island: true,
        component: component,
        props: props.to_json,
        params: params.to_json,
        instance: instance,
        stream: stream_name
      }.compact

      content_tag(:div, "", html_options.merge(data: data_attributes))
    end

    private

    def resolve_stream_name(component:, instance:, stream:)
      return nil if stream.nil?
      return stream if stream.is_a?(String)

      raise ArgumentError, "instance is required when stream: true" if instance.blank?

      "#{component}:#{instance}"
    end
  end
end
