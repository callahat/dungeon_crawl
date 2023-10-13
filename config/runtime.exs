import Config

config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  http: [
    port: System.get_env("PORT")
  ]