# frozen_string_literal: true

require_relative "../test_helper"

module Islands
  module TeamMembers
    class AddMember < Archipelago::Action
      authorize { true }

      def perform
        props members: []
      end
    end
  end

  module Admin
    module Users
      class Create < Archipelago::Action
        authorize { true }

        def perform
          props users: []
        end
      end
    end
  end
end

class ResolverTest < ArchipelagoTestCase
  class CustomHandler < Archipelago::Action
    authorize { true }

    def perform
      props override: true
    end
  end

  def setup
    super
    Archipelago.configure { |config| config.root_namespace = "Islands" }
  end

  def test_resolves_by_convention
    resolved = Archipelago::Resolver.new.resolve(component: "TeamMembers", operation: "add_member")

    assert_equal Islands::TeamMembers::AddMember, resolved
  end

  def test_resolves_namespaced_component
    resolved = Archipelago::Resolver.new.resolve(component: "Admin__Users", operation: "create")

    assert_equal Islands::Admin::Users::Create, resolved
  end

  def test_registry_override_takes_precedence
    Archipelago.map "TeamMembers#add_member" => CustomHandler

    resolved = Archipelago::Resolver.new.resolve(component: "TeamMembers", operation: "add_member")

    assert_equal CustomHandler, resolved
  end

  def test_rejects_invalid_component_name
    assert_raises(Archipelago::ResolutionError) do
      Archipelago::Resolver.new.resolve(component: "team_members", operation: "add_member")
    end
  end

  def test_rejects_invalid_operation_name
    assert_raises(Archipelago::ResolutionError) do
      Archipelago::Resolver.new.resolve(component: "TeamMembers", operation: "AddMember")
    end
  end

  def test_raises_for_missing_handler
    assert_raises(Archipelago::ResolutionError) do
      Archipelago::Resolver.new.resolve(component: "UnknownIsland", operation: "add_member")
    end
  end
end
