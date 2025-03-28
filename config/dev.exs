import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]


# Watch static and templates for browser reloading.
config :dungeon_crawl, DungeonCrawlWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg|ico|txt)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/dungeon_crawl_web/views/.*(ex)$},
      ~r{lib/dungeon_crawl_web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :libcluster,
       topologies: [
         epmd_example: [
           # The selected clustering strategy. Required.
           strategy: Cluster.Strategy.Epmd,
           # Configuration for the provided strategy. Optional.
           config: [hosts: [:"a@127.0.0.1", :"b@127.0.0.1"]],
           # The function to use for connecting nodes. The node
           # name will be appended to the argument list. Optional
           connect: {:net_kernel, :connect_node, []},
           # The function to use for disconnecting nodes. The node
           # name will be appended to the argument list. Optional
           disconnect: {:erlang, :disconnect_node, []},
           # The function to use for listing nodes.
           # This function must return a list of node names. Optional
           list_nodes: {:erlang, :nodes, [:connected]},
         ],
       ]