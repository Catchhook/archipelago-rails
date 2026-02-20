# frozen_string_literal: true

module Archipelago
  class Action
    include Archipelago::ParamsDSL

    class << self
      attr_reader :authorization_block

      def authorize(&block)
        @authorization_block = block
      end
    end

    attr_reader :ctx, :raw_params, :errors

    def initialize(ctx:, raw_params:)
      @ctx = ctx
      @raw_params = raw_params.with_indifferent_access
      @errors = Hash.new { |hash, key| hash[key] = [] }
      @coerced_params = {}
      @response_props = {}
      @redirect_location = nil
    end

    def call
      Archipelago.instrument("archipelago.action.perform", action: self.class.name) do
        @coerced_params, coercion_errors = coerce_declared_params(raw_params)
        merge_errors!(coercion_errors)
        if errors.any?
          Archipelago.instrument("archipelago.action.error", action: self.class.name, reason: "validation")
          return Archipelago::Response.error(errors: errors)
        end

        run_authorization!
        perform

        if errors.any?
          Archipelago.instrument("archipelago.action.error", action: self.class.name, reason: "validation")
          return Archipelago::Response.error(errors: errors)
        end

        if @redirect_location
          validator = Archipelago::Security::RedirectValidator.new
          location = validator.validate!(@redirect_location)
          return Archipelago::Response.redirect(location: location)
        end

        payload = Archipelago::Response.ok(props: @response_props, version: Archipelago.next_version)
        maybe_broadcast(payload)
        payload
      end
    rescue Archipelago::Forbidden
      Archipelago.instrument("archipelago.action.error", action: self.class.name, reason: "forbidden")
      Archipelago::Response.forbidden
    rescue StandardError => e
      if record_invalid_error?(e)
        map_record_invalid!(e)
        Archipelago.instrument("archipelago.action.error", action: self.class.name, reason: "record_invalid")
        Archipelago::Response.error(errors: errors)
      else
        raise
      end
    end

    def add_error(field, message)
      errors[field.to_s] << message
    end

    def props(payload)
      @response_props = payload
    end

    def redirect_to(location)
      @redirect_location = location
    end

    private

    def run_authorization!
      block = self.class.authorization_block

      if block.nil?
        raise Archipelago::MissingAuthorization if Archipelago.configuration.authorize_by_default

        return true
      end

      authorized = instance_exec(&block)
      raise Archipelago::Forbidden unless authorized

      true
    end

    def merge_errors!(incoming)
      incoming.each do |field, messages|
        messages.each { |message| add_error(field, message) }
      end
    end

    def map_record_invalid!(error)
      return unless error.record.respond_to?(:errors)

      error.record.errors.to_hash(true).each do |field, messages|
        Array(messages).each { |message| add_error(field, message) }
      end
    end

    def record_invalid_error?(error)
      defined?(ActiveRecord::RecordInvalid) && error.is_a?(ActiveRecord::RecordInvalid)
    end

    def maybe_broadcast(payload)
      stream_name = raw_params[:__stream]
      return if stream_name.blank?
      return unless payload[:status] == "ok"

      Archipelago.broadcast(stream_name, props: payload[:props], version: payload[:version])
    end
  end
end
