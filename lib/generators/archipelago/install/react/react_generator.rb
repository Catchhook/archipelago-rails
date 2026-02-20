# frozen_string_literal: true

require "rails/generators"
require "pathname"
require "json"

module Archipelago
  module Generators
    module Install
      class ReactGenerator < Rails::Generators::Base
        source_root File.expand_path("templates", __dir__)

        class_option :bundler,
                     type: :string,
                     default: "auto",
                     enum: %w[auto esbuild vite],
                     desc: "JavaScript bundler to target"

        class_option :typescript,
                     type: :string,
                     default: "auto",
                     enum: %w[auto true false],
                     desc: "Generate TSX or JSX bootstrap file"

        class_option :install,
                     type: :boolean,
                     default: false,
                     desc: "Install npm packages after generating files"

        class_option :package_manager,
                     type: :string,
                     default: "auto",
                     enum: %w[auto yarn npm pnpm bun],
                     desc: "Package manager used when --install is enabled"

        class_option :local_monorepo_path,
                     type: :string,
                     default: nil,
                     desc: "Path to local Archipelago monorepo for file: package installs"

        class_option :interactive,
                     type: :boolean,
                     default: true,
                     desc: "Prompt for setup choices with auto-detected defaults"

        class_option :auto_registry,
                     type: :boolean,
                     default: true,
                     desc: "For esbuild, auto-generate component registry from app/javascript/islands"

        desc "Sets up React + Archipelago frontend bootstrapping for a Rails app."

        def detect_stack
          @detected_bundler = detect_bundler
          @detected_typescript = detect_typescript?
          @detected_package_manager = detect_package_manager
          @detected_local_monorepo_path = detect_local_monorepo_path

          @bundler = options[:bundler] == "auto" ? @detected_bundler : options[:bundler].to_sym
          @use_typescript = case options[:typescript]
          when "true"
            true
          when "false"
            false
          else
            @detected_typescript
          end
          @should_install = options[:install]
          @package_manager = options[:package_manager] == "auto" ? @detected_package_manager : options[:package_manager]
          @local_monorepo_path = options[:local_monorepo_path] || @detected_local_monorepo_path
          @auto_registry = options[:auto_registry]
        end

        def interactive_preferences
          unless interactive_mode?
            if options[:interactive]
              say_status :info, "Interactive prompts skipped (non-TTY). Using detected/default options.", :yellow
            end
            return
          end

          say_status :info, "Interactive Archipelago React setup", :blue

          bundler_default = @bundler == :unknown ? "esbuild" : @bundler.to_s
          @bundler = ask_choice("Bundler", %w[esbuild vite], default: bundler_default).to_sym
          @use_typescript = ask_yes_no("Use TypeScript for island entry files?", default: @use_typescript)
          if @bundler == :esbuild
            @auto_registry = ask_yes_no(
              "Enable esbuild auto-registry for islands (no manual component map)?",
              default: @auto_registry
            )
          else
            @auto_registry = false
          end
          @should_install = ask_yes_no("Install frontend npm packages now?", default: @should_install)

          if @should_install
            @package_manager = ask_choice(
              "Package manager",
              %w[yarn npm pnpm bun],
              default: @package_manager
            )
          end

          @local_monorepo_path = prompt_for_local_monorepo_path(@local_monorepo_path)
        end

        def ensure_supported_stack
          if @bundler == :vite
            say_status :info, "Vite detected. Generating React entry; wire it into your Vite entrypoints.", :blue
            return
          end

          return if @bundler == :esbuild

          raise Thor::Error, "Could not detect JS bundler. Pass --bundler=esbuild or --bundler=vite."
        end

        def create_archipelago_entry
          extension = @use_typescript ? "tsx" : "jsx"
          @entry_relative_path = "app/javascript/archipelago/entry.#{extension}"
          template "entry.js.tt", @entry_relative_path
        end

        def setup_esbuild_auto_registry
          return unless @bundler == :esbuild
          return unless @auto_registry

          template "generate_registry.mjs.tt", "app/javascript/archipelago/generate_registry.mjs"
          create_file registry_relative_path, initial_registry_source
          wire_esbuild_package_scripts
        end

        def wire_esbuild_entry
          return unless @bundler == :esbuild

          app_entry = preferred_application_entry
          if app_entry.nil?
            say_status :info, "No app/javascript/application.(js|ts) file found. Import manually:", :yellow
            say "  import \"./archipelago/entry\""
            return
          end

          import_line = 'import "./archipelago/entry"'
          append_to_file app_entry, "\n#{import_line}\n" unless File.read(path_for(app_entry)).include?(import_line)
        end

        def install_packages
          return unless @should_install
          return unless path_exists?("package.json")

          if @local_monorepo_path
            run "#{resolved_package_manager} add react react-dom #{archipelago_client_package}"
            run "#{resolved_package_manager} add #{archipelago_react_package}"
          else
            run "#{resolved_package_manager} add #{packages_for_install.join(' ')}"
          end
        end

        def print_next_steps
          say ""
          say "Archipelago React frontend scaffolding created:"
          say "  #{@entry_relative_path}"
          say ""
          unless @should_install
            say "Install packages:"
            say "  #{resolved_package_manager} add #{packages_for_install.join(' ')}"
          end
          say ""
          if @bundler == :esbuild && @auto_registry
            say "Islands in app/javascript/islands/**/* are auto-registered before esbuild runs."
            say "Manual refresh command: #{script_run_command('archipelago:registry')}"
          else
            say "Register each island component in app/javascript/archipelago/entry.* under `registry`."
          end
          say "If streaming is needed, assign an ActionCable consumer to `window.Archipelago.cable`."
        end

        private

        def detect_bundler
          return :vite if gemfile_mentions?("vite_rails")
          return :vite if path_exists?("vite.config.ts") || path_exists?("vite.config.js")
          return :esbuild if gemfile_mentions?("jsbundling-rails")
          return :esbuild if path_exists?("app/javascript/application.js") || path_exists?("app/javascript/application.ts")

          :unknown
        end

        def detect_typescript?
          return true if path_exists?("tsconfig.json")
          return true if path_exists?("app/javascript/application.ts")

          false
        end

        def detect_package_manager
          return "yarn" if path_exists?("yarn.lock")
          return "pnpm" if path_exists?("pnpm-lock.yaml")
          return "bun" if path_exists?("bun.lockb")
          return "npm" if path_exists?("package-lock.json")

          "yarn"
        end

        def detect_local_monorepo_path
          candidates = []

          env_path = ENV["ARCHIPELAGO_MONOREPO_PATH"]
          candidates << Pathname.new(env_path) if env_path && !env_path.strip.empty?
          candidates << Pathname.new(destination_root).join("..", "cdx")
          candidates << Pathname.new(destination_root).join("..", "archipelago", "cdx")
          candidates << Pathname.new(__dir__).join("../../../../../../")

          candidates.map(&:expand_path).uniq.find do |candidate|
            local_packages_available?(candidate)
          end&.to_s
        end

        def preferred_application_entry
          return "app/javascript/application.ts" if path_exists?("app/javascript/application.ts")
          return "app/javascript/application.js" if path_exists?("app/javascript/application.js")

          nil
        end

        def gemfile_mentions?(name)
          return false unless path_exists?("Gemfile")

          File.read(path_for("Gemfile")).include?(name)
        end

        def resolved_package_manager
          @package_manager
        end

        def packages_for_install
          [
            "react",
            "react-dom",
            archipelago_client_package,
            archipelago_react_package
          ]
        end

        def registry_relative_path
          extension = @use_typescript ? "ts" : "js"
          "app/javascript/archipelago/registry.generated.#{extension}"
        end

        def initial_registry_source
          if @use_typescript
            <<~TS
              import type { IslandRegistry } from "@archipelago/react"

              // Auto-generated by Archipelago. Run `#{script_run_command('archipelago:registry')}` to refresh.
              const registry: IslandRegistry = {}

              export default registry
            TS
          else
            <<~JS
              // Auto-generated by Archipelago. Run `#{script_run_command('archipelago:registry')}` to refresh.
              const registry = {}

              export default registry
            JS
          end
        end

        def wire_esbuild_package_scripts
          return unless path_exists?("package.json")

          package_json_path = path_for("package.json")
          package_json = JSON.parse(File.read(package_json_path))
          scripts = package_json["scripts"] ||= {}
          registry_command = "node app/javascript/archipelago/generate_registry.mjs"

          scripts["archipelago:registry"] ||= registry_command

          scripts.each do |name, command|
            next unless command.is_a?(String)
            next unless command.include?("esbuild")
            next if command.include?("archipelago:registry") || command.include?("generate_registry.mjs")

            scripts[name] = "#{registry_command} && #{command}"
          end

          File.write(package_json_path, "#{JSON.pretty_generate(package_json)}\n")
        end

        def path_exists?(relative_path)
          File.exist?(path_for(relative_path))
        end

        def path_for(relative_path)
          File.expand_path(relative_path, destination_root)
        end

        def script_run_command(script_name)
          case resolved_package_manager
          when "npm"
            "npm run #{script_name}"
          when "pnpm"
            "pnpm #{script_name}"
          when "bun"
            "bun run #{script_name}"
          else
            "yarn #{script_name}"
          end
        end

        def interactive_mode?
          options[:interactive] && $stdin.tty? && $stdout.tty?
        end

        def ask_choice(label, choices, default:)
          answer = ask("#{label} [#{choices.join('/')}] (default: #{default})")
          normalized = answer.to_s.strip
          normalized = default if normalized.empty?
          return normalized if choices.include?(normalized)

          say_status :warning, "Invalid choice '#{normalized}', using '#{default}'.", :yellow
          default
        end

        def ask_yes_no(question, default:)
          answer = ask("#{question} [#{default ? 'Y/n' : 'y/N'}]")
          normalized = answer.to_s.strip.downcase
          return default if normalized.empty?
          return true if %w[y yes].include?(normalized)
          return false if %w[n no].include?(normalized)

          say_status :warning, "Invalid answer '#{answer}', using default.", :yellow
          default
        end

        def prompt_for_local_monorepo_path(current_path)
          if current_path
            use_detected = ask_yes_no(
              "Use local Archipelago packages from #{current_path}?",
              default: true
            )
            return current_path if use_detected
          end

          entered = ask("Local Archipelago monorepo path for file: installs (leave blank to use npm registry)")
          normalized = entered.to_s.strip
          return nil if normalized.empty?

          root = Pathname.new(normalized).expand_path
          unless local_packages_available?(root)
            say_status :warning, "No packages/client and packages/react under #{root}; using npm registry.", :yellow
            return nil
          end

          root.to_s
        end

        def local_packages_available?(root)
          root.join("packages/client").directory? && root.join("packages/react").directory?
        end

        def archipelago_client_package
          return "@archipelago/client" unless @local_monorepo_path

          root = Pathname.new(@local_monorepo_path).expand_path
          "@archipelago/client@file:#{root.join('packages/client')}"
        end

        def archipelago_react_package
          return "@archipelago/react" unless @local_monorepo_path

          root = Pathname.new(@local_monorepo_path).expand_path
          "@archipelago/react@file:#{root.join('packages/react')}"
        end
      end
    end
  end
end
