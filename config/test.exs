import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Configure your database
config :dungeon_crawl, DungeonCrawl.Repo,
  pool: Ecto.Adapters.SQL.Sandbox

config :bcrypt_elixir, :log_rounds, 4

config :dungeon_crawl, :generator, DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms
config :dungeon_crawl, :generators, [DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms]

config :phoenix, :plug_init_mode, :runtime


config :libcluster,
       topologies: [
         test: [
           # The selected clustering strategy. Required.
           strategy: Cluster.Strategy.Epmd,
           # Configuration for the provided strategy. Optional.
           config: [hosts: [:"nonode@nohost"]],
         ],
       ]