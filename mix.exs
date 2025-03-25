defmodule DungeonCrawl.Mixfile do
  use Mix.Project

  def project do
    [app: :dungeon_crawl,
     version: "0.0.2",
     elixir: "~> 1.17",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [
       coveralls: :test,
       "coveralls.detail": :test,
       "coveralls.post": :test,
       "coveralls.html": :test
     ],
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {DungeonCrawl.Application, []},
#     applications: [:phoenix, :phoenix_pubsub, :phoenix_html, :cowboy, :logger, :gettext,
#                    :phoenix_ecto, :postgrex, :comeonin]]
      extra_applications: [:logger, :runtime_tools, :os_mon, :observer, :wx]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.7"},
     {:phoenix_ecto, "~> 4.0"},
     {:ecto_psql_extras, "~> 0.7"},
     {:postgrex, ">= 0.0.0"},
     {:phoenix_html, "~> 3.0"},
     {:phoenix_live_reload, "~> 1.3", only: :dev},
     {:phoenix_live_dashboard, "~> 0.5"},
     {:telemetry_metrics, "~> 0.6"},
     {:telemetry_poller, "~> 0.5"},
     {:gettext, "~> 0.11"},
     {:jason, "~> 1.0"},
     {:plug_cowboy, "~> 2.5"},
     {:comeonin, "~> 5.3"},
     {:bcrypt_elixir, "~> 3.0"},
     {:poolboy, "~> 1.5.1"},
     {:excoveralls, "~> 0.10", only: :test},
     {:benchee, "~> 1.0", only: :dev},
     {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
     {:floki, ">= 0.30.0", only: :test},
     {:assert_eventually, "~> 1.0.0", only: :test},
     {:phoenix_view, "~> 2.0"},
     {:phoenix_live_view, "~> 0.20"},
     {:dotenvy, "~> 0.8"},
     {:libcluster, "~> 3.3"},
     {:horde, "~> 0.9"},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate", "test --exclude horde"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"],
    ]
  end
end
