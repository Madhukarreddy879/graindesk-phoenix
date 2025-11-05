# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Session and authentication configuration
config :rice_mill,
  session_timeout_hours: 24,
  low_stock_threshold: 50,
  dashboard_cache_ttl_seconds: 30

config :rice_mill, :scopes,
  user: [
    default: true,
    module: RiceMill.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: RiceMill.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :rice_mill,
  ecto_repos: [RiceMill.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :rice_mill, RiceMillWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: RiceMillWeb.ErrorHTML, json: RiceMillWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RiceMill.PubSub,
  live_view: [signing_salt: "K9rjkuN2"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :rice_mill, RiceMill.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  rice_mill: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  rice_mill: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure PDF Generator
config :pdf_generator,
  wkhtml_path: "/usr/bin/wkhtmltopdf",
  raise_on_missing_wkhtmltopdf_binary: false,
  command_prefix: ""

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
