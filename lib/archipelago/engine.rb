# frozen_string_literal: true

require "rails/engine"

module Archipelago
  class Engine < ::Rails::Engine
    isolate_namespace Archipelago

    initializer "archipelago.view_helper" do
      ActiveSupport.on_load(:action_view) do
        include Archipelago::ViewHelper
      end
    end

    initializer "archipelago.test_helpers" do
      ActiveSupport.on_load(:action_dispatch_integration_test) do
        include Archipelago::TestHelpers
      end
    end
  end
end
