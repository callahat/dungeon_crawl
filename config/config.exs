# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# General application configuration
config :dungeon_crawl,
  ecto_repos: [DungeonCrawl.Repo]

# Configures the endpoint
config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  secret_key_base: "uAZt6ZmV0dMClEWZB0FaHEiFnrOJvA487Lw6QxTGuTPsJ0U1EJgslK7+pbdTIzZW",
  render_errors: [view: DungeonCrawlWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: DungeonCrawl.PubSub,
  live_view: [signing_salt: "SECRET_SALT"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time [$level] <$metadata> $message\n",
  metadata: [:request_id]

# Configure esbuild (the version is required)
config :esbuild,
       version: "0.14.11",
       default: [
         args: ~w(
           js/app.js
           --bundle
           --target=es2016
           --outdir=../priv/static/assets
           --external:/fonts/*
           --external:/images/*
           --loader:.woff=file
           --loader:.woff2=file
           --loader:.svg=file
           --loader:.eot=file
           --loader:.ttf=file
         ),
         cd: Path.expand("../assets", __DIR__),
         env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)},
       ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
