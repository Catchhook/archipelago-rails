# frozen_string_literal: true

module Archipelago
  class Registry
    def initialize
      @map = {}
    end

    def map(key, handler)
      @map[key] = handler
    end

    def resolve(key)
      @map[key]
    end

    def to_h
      @map.dup
    end

    def clear!
      @map.clear
    end
  end
end
