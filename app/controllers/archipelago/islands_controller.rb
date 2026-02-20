# frozen_string_literal: true

module Archipelago
  class IslandsController < ApplicationController
    rescue_from Archipelago::ResolutionError, with: :render_not_found
    rescue_from Archipelago::MissingAuthorization, with: :render_forbidden
    rescue_from Archipelago::Forbidden, with: :render_forbidden
    rescue_from Archipelago::InvalidOrigin, with: :render_forbidden
    rescue_from Archipelago::InvalidRedirect, with: :render_invalid_redirect

    def create
      validate_origin!

      action_class = resolver.resolve(component: params[:component], operation: params[:operation])
      action = action_class.new(ctx: request_context, raw_params: island_params)
      payload = action.call

      render json: payload, status: rack_status_for(payload)
    end

    def debug
      return head :not_found unless Rails.env.development? || Rails.env.test?

      render json: debug_payload
    end

    private

    def resolver
      @resolver ||= Archipelago::Resolver.new
    end

    def request_context
      Archipelago::Context.new(
        request: request,
        params: params,
        session: session,
        user: current_archipelago_user
      )
    end

    def current_archipelago_user
      resolver_proc = Archipelago.configuration.current_user_resolver
      return instance_exec(&resolver_proc) if resolver_proc

      method_name = Archipelago.configuration.current_user_method
      return send(method_name) if respond_to?(method_name, true)

      nil
    end

    def validate_origin!
      Archipelago::Security::OriginValidator.new(request).validate!
    end

    def island_params
      params.to_unsafe_h.except(:component, :operation, :controller, :action)
    end

    def rack_status_for(payload)
      case payload[:status]
      when "ok", "redirect", "error"
        :ok
      when "forbidden"
        :forbidden
      else
        :ok
      end
    end

    def render_not_found
      head :not_found
    end

    def render_forbidden
      render json: Archipelago::Response.forbidden, status: :forbidden
    end

    def render_invalid_redirect(exception)
      render json: Archipelago::Response.error(errors: { base: [exception.message] }), status: :unprocessable_entity
    end

    def debug_payload
      {
        root_namespace: Archipelago.configuration.root_namespace,
        registry: Archipelago.registry.to_h.transform_values(&:name),
        actions: debug_actions_from_files,
        registry_actions: debug_actions_from_registry
      }
    end

    def debug_actions_from_files
      files = Dir.glob(Rails.root.join("app/islands/**/*.rb")).sort

      files.map do |file_path|
        relative = file_path.delete_prefix("#{Rails.root}/app/islands/").delete_suffix(".rb")
        *component_parts, operation = relative.split("/")
        component = component_parts.map(&:camelize).join("__")
        handler_name = [
          Archipelago.configuration.root_namespace,
          *component_parts.map(&:camelize),
          operation.camelize
        ].join("::")
        handler_class = handler_name.safe_constantize

        {
          source: "filesystem",
          component: component,
          operation: operation,
          file: file_path.delete_prefix("#{Rails.root}/"),
          handler: handler_name,
          params: debug_param_schema_for(handler_class)
        }
      end
    end

    def debug_actions_from_registry
      Archipelago.registry.to_h.map do |key, handler|
        component, operation = key.split("#", 2)
        {
          source: "registry",
          component: component,
          operation: operation,
          handler: handler.name,
          params: debug_param_schema_for(handler)
        }
      end.sort_by { |entry| [entry[:component].to_s, entry[:operation].to_s] }
    end

    def debug_param_schema_for(handler_class)
      return [] unless handler_class.respond_to?(:param_definitions)

      handler_class.param_definitions.values.map do |definition|
        {
          name: definition.name.to_s,
          type: definition.type.to_s,
          required: definition.required,
          default: debug_param_default(definition.default),
          transforms: {
            strip: definition.strip,
            downcase: definition.downcase,
            upcase: definition.upcase
          }
        }
      end
    end

    def debug_param_default(value)
      if value == Archipelago::ParamsDSL::MISSING
        { provided: false }
      elsif value.respond_to?(:call)
        { provided: true, kind: "callable" }
      else
        { provided: true, value: value }
      end
    end
  end
end
