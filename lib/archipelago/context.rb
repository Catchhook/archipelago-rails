# frozen_string_literal: true

module Archipelago
  class Context
    attr_reader :request, :params, :session, :user
    attr_accessor :stream

    def initialize(request:, params:, session:, user: nil, stream: nil)
      @request = request
      @params = params
      @session = session
      @user = user
      @stream = stream
    end
  end
end
