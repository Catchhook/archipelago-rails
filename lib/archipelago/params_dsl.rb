# frozen_string_literal: true

require "date"
require "time"

module Archipelago
  module ParamsDSL
    MISSING = Object.new.freeze

    ParamDefinition = Struct.new(
      :name,
      :type,
      :required,
      :default,
      :strip,
      :downcase,
      :upcase,
      :in,
      :format,
      :min,
      :max,
      :empty_as_nil,
      :of,
      :validate,
      keyword_init: true
    )

    module ClassMethods
      def param_definitions
        @param_definitions ||= {}
      end

      def param(name, type, required: false, default: MISSING, strip: false, downcase: false, upcase: false,
                in: nil, format: nil, min: nil, max: nil, empty_as_nil: false, of: nil, validate: nil)
        symbol_name = name.to_sym

        param_definitions[symbol_name] = ParamDefinition.new(
          name: symbol_name,
          type: type,
          required: required,
          default: default,
          strip: strip,
          downcase: downcase,
          upcase: upcase,
          in: binding.local_variable_get(:in),
          format: format,
          min: min,
          max: max,
          empty_as_nil: empty_as_nil,
          of: of,
          validate: validate
        )

        define_method(symbol_name) do
          @coerced_params[symbol_name]
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def coerce_declared_params(raw_params)
      coerced = {}
      errors = Hash.new { |hash, key| hash[key] = [] }

      self.class.param_definitions.each_value do |definition|
        raw_value = fetch_param(raw_params, definition.name)

        if definition.empty_as_nil && empty_string?(raw_value)
          raw_value = nil
        end

        if blank_value?(raw_value)
          if definition.default != MISSING
            coerced[definition.name] = definition.default.respond_to?(:call) ? definition.default.call : definition.default
          elsif definition.required
            errors[definition.name.to_s] << "is required"
          end

          next
        end

        begin
          coerced_value = coerce_value(raw_value, definition)
          validation_error = run_validations(coerced_value, definition)
          if validation_error
            errors[definition.name.to_s] << validation_error
          else
            coerced[definition.name] = coerced_value
          end
        rescue ArgumentError, TypeError, JSON::ParserError
          errors[definition.name.to_s] << "is invalid"
        end
      end

      [coerced, errors]
    end

    private

    def fetch_param(raw_params, key)
      raw_params[key] || raw_params[key.to_s]
    end

    def blank_value?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def empty_string?(value)
      value.is_a?(String) && value.strip.empty?
    end

    def coerce_value(raw_value, definition)
      value = cast(raw_value, definition.type)

      if definition.type == :array && definition.of
        value = value.map { |element| cast(element, definition.of) }
      end

      return value unless value.is_a?(String)

      value = value.strip if definition.strip
      value = value.downcase if definition.downcase
      value = value.upcase if definition.upcase
      value
    end

    def run_validations(value, definition)
      if definition.in && !definition.in.include?(value)
        return "is not included in the list"
      end

      if definition.format && value.is_a?(String) && !value.match?(definition.format)
        return "is invalid"
      end

      if definition.min
        comparable = value.respond_to?(:length) ? value.length : value
        return "is too small" if comparable < definition.min
      end

      if definition.max
        comparable = value.respond_to?(:length) ? value.length : value
        return "is too large" if comparable > definition.max
      end

      if definition.validate
        custom_error = definition.validate.call(value)
        return custom_error if custom_error.is_a?(String)
      end

      nil
    end

    def cast(value, type)
      case type
      when :string
        String(value)
      when :integer
        Integer(value)
      when :boolean
        cast_boolean(value)
      when :float
        Float(value)
      when :date
        Date.parse(String(value))
      when :datetime
        Time.parse(String(value))
      when :array
        cast_array(value)
      when :json
        cast_json(value)
      else
        raise ArgumentError, "Unsupported param type: #{type}"
      end
    end

    def cast_boolean(value)
      return true if [true, 1, "1", "true", "on", "yes"].include?(value)
      return false if [false, 0, "0", "false", "off", "no"].include?(value)

      raise TypeError, "Invalid boolean value"
    end

    def cast_array(value)
      return value if value.is_a?(Array)

      parsed = JSON.parse(String(value))
      raise TypeError, "Array expected" unless parsed.is_a?(Array)

      parsed
    end

    def cast_json(value)
      return value if value.is_a?(Hash) || value.is_a?(Array)

      JSON.parse(String(value))
    end
  end
end
