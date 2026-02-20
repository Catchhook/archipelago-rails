# frozen_string_literal: true

module Archipelago
  class Context
    attr_reader :request, :params, :session, :user

    def initialize(request:, params:, session:, user: nil)
      @request = request
      @params = params
      @session = session
      @user = user
    end
  end
end
