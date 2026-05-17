# frozen_string_literal: true

module Archipelago
  module PunditAdapter
    def authorize(record, query = nil)
      query ||= infer_pundit_query
      policy = policy(record)

      unless policy.public_send(query)
        raise Archipelago::Forbidden, "not allowed to #{query} this #{record.class}"
      end

      record
    end

    def policy(record)
      klass = "#{record.class}Policy".safe_constantize
      raise Archipelago::Forbidden, "no policy found for #{record.class}" unless klass

      klass.new(current_user, record)
    end

    private

    def infer_pundit_query
      action_name = self.class.name.to_s.demodulize.sub(/Action\z/, "").underscore
      "#{action_name}?"
    end
  end
end
