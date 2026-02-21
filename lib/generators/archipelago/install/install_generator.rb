# frozen_string_literal: true

require "rails/generators"

module Archipelago
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Installs Archipelago into a Rails app"

      def create_islands_directory
        empty_directory "app/islands"
      end

      def create_initializer
        create_file "config/initializers/archipelago.rb", <<~RUBY
          Archipelago.configure do |config|
            config.root_namespace = "Islands"
            config.current_user_method = :current_user
            config.authorize_by_default = true
            config.strict_origin_check = false
            config.allowed_redirect_hosts = []
          end
        RUBY
      end

      def mount_engine
        route_line = "mount Archipelago::Engine => \"/islands\""
        routes_path = "config/routes.rb"

        if File.exist?(routes_path) && !File.read(routes_path).include?(route_line)
          route(route_line)
        end
      end

      def print_next_steps
        say "If package install fails on Yarn mirror, add to .npmrc:"
        say "  @archipelago-js:registry=https://registry.npmjs.org"
        say "Install JS packages: yarn add @archipelago-js/client @archipelago-js/react"
        say "Optional React bootstrap wizard: rails g archipelago:install:react"
        say "Non-interactive mode: rails g archipelago:install:react --interactive=false"
        say "esbuild users get auto-registry wiring by default in install:react"
      end
    end
  end
end
