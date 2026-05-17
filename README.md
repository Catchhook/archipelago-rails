# archipelago-rails

Rails engine for Archipelago — server-driven React islands with Inertia-style props, form handling, and real-time updates via ActionCable.

## Install

Add to your Gemfile:

```ruby
gem "archipelago-rails"
```

Then run the install generator:

```bash
rails g archipelago:install
```

### React setup (esbuild)

```bash
rails g archipelago:install:react
```

This scaffolds frontend bootstrap wiring. Options:

```bash
rails g archipelago:install:react --interactive=false --bundler=esbuild --typescript=true
rails g archipelago:install:react --lazy_registry   # dynamic imports instead of eager
rails g archipelago:install:react --install          # install npm packages immediately
```

## Core Concepts

Archipelago lets you embed interactive React components ("islands") inside server-rendered Rails views. Each island receives **props from the server** and can call **server-side actions** that return updated props, errors, or redirects.

```
┌─────────────────────────────────────┐
│  Rails View                         │
│  ┌───────────────────┐              │
│  │  React Island     │ ← props      │
│  │  (TeamMembers)    │              │
│  │  ┌─────────────┐  │              │
│  │  │ Add Member  │──┼─→ Action     │
│  │  │ Form        │  │   (server)   │
│  │  └─────────────┘  │              │
│  └───────────────────┘              │
└─────────────────────────────────────┘
```

## Building Actions

Actions live in `app/islands/<component>/` and handle requests from island components.

### Basic action

```ruby
# app/islands/team_members/add_member.rb
class TeamMembers::AddMember < Archipelago::Action
  param :email, :string, required: true, strip: true, downcase: true

  authorize { current_user.admin? }

  def perform
    member = Team.find(raw_params[:team_id]).members.create!(email: email)

    props(
      members: Team.find(raw_params[:team_id]).members.map { |m| { id: m.id, email: m.email } }
    )
  end
end
```

### Action lifecycle

1. **Param coercion** — declared params are validated and coerced
2. **Authorization** — the `authorize` block runs (raises `Forbidden` on failure)
3. **`perform`** — your business logic executes
4. **Response** — returns `ok` (with props), `error` (with field errors), `redirect`, or `forbidden`

### Response helpers

```ruby
def perform
  # Return updated props
  props(members: [...])

  # Or redirect
  redirect_to "/teams/#{team.id}"

  # Or add field errors
  add_error(:email, "is already taken")
end
```

### `current_user`

Available in all actions, delegating to the configured user method:

```ruby
def perform
  team = current_user.teams.find(raw_params[:team_id])
  # ...
end
```

### ActiveRecord::RecordInvalid

Archipelago automatically catches `ActiveRecord::RecordInvalid` exceptions and maps them to field-level error responses.

## Params DSL

Declare expected parameters with type coercion, validation, and transformation:

```ruby
class TeamMembers::UpdateSettings < Archipelago::Action
  param :name,     :string,  required: true, strip: true, min: 2, max: 100
  param :email,    :string,  required: true, format: /\A[^@\s]+@[^@\s]+\z/
  param :role,     :string,  required: true, in: %w[admin member viewer]
  param :bio,      :string,  empty_as_nil: true
  param :age,      :integer, min: 13, max: 150
  param :score,    :float
  param :active,   :boolean, default: true
  param :tags,     :array,   of: :string
  param :metadata, :json
  param :starts_on, :date
  param :due_at,    :datetime
  param :nickname, :string, validate: ->(v) { "is offensive" if offensive?(v) }

  # Params become methods: name, email, role, bio, etc.
  def perform
    user = current_user
    user.update!(name: name, email: email, role: role, bio: bio)
    props(user: serialize(user))
  end
end
```

### Supported types

| Type | Coercion |
|------|----------|
| `:string` | `String(value)` |
| `:integer` | `Integer(value)` |
| `:float` | `Float(value)` |
| `:boolean` | `true/1/"1"/"true"/"on"/"yes"` → `true`, etc. |
| `:date` | `Date.parse(value)` |
| `:datetime` | `Time.parse(value)` |
| `:array` | Pass-through or `JSON.parse`, with optional `of:` typed elements |
| `:json` | Pass-through or `JSON.parse` |

### Validation options

| Option | Description |
|--------|-------------|
| `required: true` | Rejects blank/nil values |
| `default: value` | Fallback when missing (supports lambdas) |
| `strip: true` | Strip whitespace (strings only) |
| `downcase: true` | Downcase (strings only) |
| `upcase: true` | Upcase (strings only) |
| `in: [...]` | Value must be in the list |
| `format: /regex/` | String must match pattern |
| `min: n` | Minimum value or length |
| `max: n` | Maximum value or length |
| `empty_as_nil: true` | Treat `""` / whitespace-only as `nil` |
| `of: :type` | Element type for arrays |
| `validate: ->(v) { ... }` | Custom validator; return error string or nil |

## Authorization

### Per-action authorization

Every action should define an `authorize` block:

```ruby
class TeamMembers::AddMember < Archipelago::Action
  authorize { current_user.admin? }

  def perform
    # ...
  end
end
```

When `authorize_by_default` is `true` (the default), actions without an `authorize` block raise `MissingAuthorization`.

### Pundit adapter

Include `Archipelago::PunditAdapter` for Pundit-style authorization:

```ruby
class TeamMembers::AddMember < Archipelago::Action
  include Archipelago::PunditAdapter

  authorize { authorize(@team, :add_member?) }

  def perform
    @team = Team.find(raw_params[:team_id])
    authorize(@team) # infers query from action name
    # ...
  end
end
```

The adapter provides:
- `authorize(record, query = nil)` — raises `Forbidden` if policy denies
- `policy(record)` — returns the policy instance

### CanCan adapter

Include `Archipelago::CanCanAdapter` for CanCan-style authorization:

```ruby
class TeamMembers::AddMember < Archipelago::Action
  include Archipelago::CanCanAdapter

  def perform
    team = Team.find(raw_params[:team_id])
    authorize!(:manage, team)
    # ...
  end
end
```

The adapter provides:
- `authorize!(action, record)` — raises `Forbidden` if ability denies
- `current_ability` — returns the ability instance

Configure the ability builder if you don't use a top-level `Ability` class:

```ruby
Archipelago.configure do |config|
  config.current_ability = ->(user) { CustomAbility.new(user) }
end
```

## Stream Authorization

ActionCable streams can be authorized before subscription:

```ruby
Archipelago.configure do |config|
  config.stream_authorizer = ->(connection:, stream_name:, params:) {
    user = connection.current_user
    # stream_name is e.g. "TeamMembers:42"
    team_id = stream_name.split(":").last.to_i
    user.teams.exists?(id: team_id)
  }

  # Reject all streams that don't pass through the authorizer
  config.require_stream_authorization = true
end
```

When `require_stream_authorization` is `true`, any stream without a configured authorizer is rejected. When `false` (default), streams are allowed unless an authorizer explicitly denies them.

**Important:** If your streams carry tenant-specific or user-specific data, always configure a `stream_authorizer` or enable `require_stream_authorization`.

## Configuration

```ruby
# config/initializers/archipelago.rb
Archipelago.configure do |config|
  config.root_namespace = "Islands"              # where actions live under app/islands/
  config.current_user_method = :current_user     # controller method for current user
  config.authorize_by_default = true             # require authorize blocks
  config.strict_origin_check = false             # validate redirect origins
  config.allowed_redirect_hosts = []             # allowed redirect hosts
  config.stream_authorizer = nil                 # ActionCable stream auth lambda
  config.require_stream_authorization = false    # reject unauthed streams
  config.current_ability = nil                   # CanCan ability builder
end
```

## Response Contract

All action responses follow a standard JSON shape:

```json
// ok — updated props
{ "status": "ok", "props": { ... }, "version": 1716000000000 }

// error — field-level validation errors
{ "status": "error", "errors": { "email": ["can't be blank"] } }

// redirect
{ "status": "redirect", "location": "/teams/1" }

// forbidden
{ "status": "forbidden" }
```

The `version` field is a monotonic timestamp used by the client to prevent stale broadcasts from overwriting newer data.

## Streams & Broadcasting

When a client sends the `X-Archipelago-Stream` header (or the legacy `__stream` param), successful action responses are automatically broadcast to all subscribers of that stream.

On the client side, `useIslandProps({ stream: "TeamMembers:42" })` auto-subscribes to the stream and merges broadcast props into the component.

## Supported Rails versions

- Rails `>= 7.1`, `< 9.0`

## Development

```bash
bundle install
```

### Run tests

```bash
bin/test                          # full suite
bundle exec rake test:core        # core unit tests
bundle exec rake test:rails       # rails integration tests
```

### Rails version matrix (Appraisal)

```bash
bundle exec appraisal install
bin/test-appraisal rails-7-1
bin/test-appraisal rails-7-2
bin/test-appraisal rails-8-1
```

## License

MIT
