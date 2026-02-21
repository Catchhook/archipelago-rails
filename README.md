# archipelago-rails

Rails engine for Archipelago server-driven React islands.

## Supported Rails versions

- Rails `>= 7.1`

## Development setup

```bash
bundle install
```

## Run tests

```bash
# full suite (core + rails integration tests)
bin/test

# split tasks
bundle exec rake test:core
bundle exec rake test:rails
```

## Rails version matrix (Appraisal)

```bash
bundle exec appraisal install
bin/test-appraisal rails-7-1
bin/test-appraisal rails-7-2
bin/test-appraisal rails-8-1
```

## Notes

- Controller/generator tests run against an in-test Rails application harness.
- JS packages are tested from repository root via `yarn test`.

## Host app setup (React + esbuild)

After `rails g archipelago:install`, you can scaffold frontend bootstrap wiring:

```bash
rails g archipelago:install:react
```

The generator writes `.npmrc` with:

```text
@archipelago-js:registry=https://registry.npmjs.org
```

This keeps installs reliable across npm, Yarn classic, pnpm, and bun.

By default this runs an interactive wizard with auto-detected defaults
(bundler, TypeScript, package manager, and local monorepo path).

For esbuild apps, the wizard also enables auto-registry by default:
- scans `app/javascript/islands/**/*.{js,jsx,ts,tsx}`
- writes `app/javascript/archipelago/registry.generated.(js|ts)`
- wires `package.json` esbuild scripts to run generator first

Useful options:

```bash
# disable prompts and use flags only
rails g archipelago:install:react --interactive=false --bundler=esbuild --typescript=true

# force TSX output
rails g archipelago:install:react --typescript=true

# disable auto-registry and keep manual registry map in entry file
rails g archipelago:install:react --auto_registry=false

# install npm packages immediately
rails g archipelago:install:react --install

# install Archipelago packages from a local monorepo path
rails g archipelago:install:react --install --local-monorepo-path=/absolute/path/to/cdx
```

Manual refresh command (if needed while a long-running watch is already running):

```bash
yarn archipelago:registry
```
