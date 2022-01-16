import Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or you later on).
config :dungeon_crawl, DungeonCrawl.Endpoint,
  secret_key_base: System.get_env("SECRET_KEY_BASE")
  live_view: [signing_salt: System.get_env("LIVEVIEW_SECRET_SALT")]

# Configure your database
config :dungeon_crawl, DungeonCrawl.Repo,
  ssl: true,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("DATABASE_USERNAME"),
  password: System.get_env("DATABASE_PASSWORD"),
  database: "dungeon_crawl_prod",
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
