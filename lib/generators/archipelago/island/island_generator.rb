# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module Archipelago
  module Generators
    class IslandGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :operations, type: :array, default: [], banner: "operation operation"

      def ensure_operations
        raise ArgumentError, "At least one operation is required" if operations.empty?
      end

      def create_action_files
        operations.each do |operation|
          @operation = operation
          template "action.rb.tt", File.join("app/islands", file_path, "#{operation}.rb")
        end
      end

      def create_component_file
        @component_name = class_name
        template "component.tsx.tt", File.join("app/javascript/islands", "#{class_name}.tsx")
      end

      private

      def component_module_parts
        class_name.split("::")
      end

      def component_module
        component_module_parts.join("::")
      end

      def operation_class
        @operation.camelize
      end
    end
  end
end
