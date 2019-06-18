# DungeonCrawl

To start your Phoenix app:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Alternatively you may just want to load the schema with `mix ecto.load`, as the migrations are largely unstable as the schema has changed much during development.
  * Load the seeds for basic tiles, and generate a joinable map with `mix run priv/repo/basic_tile_template_seeds.exs` and `mix run priv/repo/joinable_dungeon_seeds.exs`
  * Install Node.js dependencies with `npm install`
  * Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
