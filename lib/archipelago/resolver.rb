# frozen_string_literal: true

module Archipelago
  class Resolver
    COMPONENT_PATTERN = /\A[A-Z][A-Za-z0-9_]*\z/
    OPERATION_PATTERN = /\A[a-z][a-z0-9_]*\z/

    def initialize(configuration: Archipelago.configuration, registry: Archipelago.registry)
      @configuration = configuration
      @registry = registry
    end

    def resolve(component:, operation:)
      Archipelago.instrument(
        "archipelago.action.resolve",
        component: component,
        operation: operation
      ) do
        validate!(component: component, operation: operation)

        override = @registry.resolve("#{component}##{operation}")
        return validate_handler!(override) if override

        constant_name = convention_constant_name(component: component, operation: operation)
        klass = constant_name.safe_constantize
        raise Archipelago::ResolutionError, "Unknown island action" unless klass

        validate_handler!(klass)
      end
    end

    private

    def validate!(component:, operation:)
      raise Archipelago::ResolutionError, "Invalid component name" unless component.match?(COMPONENT_PATTERN)
      raise Archipelago::ResolutionError, "Invalid operation name" unless operation.match?(OPERATION_PATTERN)
    end

    def validate_handler!(handler)
      unless handler.is_a?(Class) && handler < Archipelago::Action
        raise Archipelago::ResolutionError, "Resolved handler must inherit from Archipelago::Action"
      end

      handler
    end

    def convention_constant_name(component:, operation:)
      component_parts = component.split("__").map { |part| part.underscore.camelize }
      operation_class = operation.camelize

      [@configuration.root_namespace, *component_parts, operation_class].join("::")
    end
  end
end
