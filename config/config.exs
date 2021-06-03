# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# General application configuration
config :dungeon_crawl,
  ecto_repos: [DungeonCrawl.Repo]

# Configures the endpoint
config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "uAZt6ZmV0dMClEWZB0FaHEiFnrOJvA487Lw6QxTGuTPsJ0U1EJgslK7+pbdTIzZW",
  render_errors: [view: DungeonCrawlWeb.ErrorView, accepts: ~w(html json)],
  pubsub_server: DungeonCrawl.PubSub,
  live_view: [signing_salt: "SECRET_SALT"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time $metadata [$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
