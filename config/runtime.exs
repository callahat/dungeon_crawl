import Config
import Dotenvy

dir = System.get_env("RELEASE_ROOT") || "envs/"

source!([
  "#{dir}env",
  "#{dir}env.#{config_env()}",
  "#{dir}env.#{config_env()}.local",
  System.get_env()
])

config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  http: [
    port: env!("PORT", :integer) || 4000
  ]

config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
       secret_key_base: env!("SECRET_KEY_BASE", :string!),
       live_view: [signing_salt: env!("LIVEVIEW_SECRET_SALT", :string!)]

# Configure your database
config :dungeon_crawl, DungeonCrawl.Repo,
       adapter: Ecto.Adapters.Postgres,
       ssl: env!("DATABASE_SSL", :boolean?),
       url: env!("DATABASE_URL", :string),
       username: env!("DATABASE_USERNAME", :string!),
       password: env!("DATABASE_PASSWORD", :string!),
       database: env!("DATABASE", :string!),
       hostname: env!("DATABASE_HOSTNAME", :string!),
       pool_size: env!("POOL_SIZE", :integer) || 10
