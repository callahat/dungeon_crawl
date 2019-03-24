use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dungeon_crawl, DungeonCrawl.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :dungeon_crawl, DungeonCrawl.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "elixir",
  password: "elixir",
  database: "dungeon_crawl_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
