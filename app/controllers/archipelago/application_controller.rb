# frozen_string_literal: true

require "action_controller/base"

module Archipelago
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    skip_forgery_protection if defined?(Rails) && Rails.env.test?
  end
end
