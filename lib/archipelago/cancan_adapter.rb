# frozen_string_literal: true

module Archipelago
  module CanCanAdapter
    def authorize!(action, record)
      ability = current_ability
      unless ability.can?(action, record)
        raise Archipelago::Forbidden, "not allowed to #{action} this #{record.class}"
      end

      record
    end

    def current_ability
      ability_builder = Archipelago.configuration.current_ability
      if ability_builder
        ability_builder.call(current_user)
      elsif defined?(::Ability)
        ::Ability.new(current_user)
      else
        raise Archipelago::Error, "No ability class configured. Set Archipelago.configuration.current_ability or define an Ability class."
      end
    end
  end
end
