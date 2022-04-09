defmodule DungeonCrawl.Application do
  use Application

  defp dock_worker_config do
    [
      name: {:local, :dock_worker},
      worker_module: DungeonCrawl.Shipping.DockWorker,
      size: 2,
      max_overflow: 5
    ]
  end

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      # Start the PubSub system
      {Phoenix.PubSub, name: DungeonCrawl.PubSub},
      # Start the Ecto repository
      DungeonCrawl.Repo,
      # Start the telemetry
      DungeonCrawlWeb.Telemetry,
      # Start the endpoint when the application starts
      DungeonCrawlWeb.Endpoint,
      # Start the worker for import and export
      :poolboy.child_spec(:dock_worker, dock_worker_config()),
      # Start your own worker by calling: DungeonCrawlWeb.Worker.start_link(arg1, arg2, arg3)
      # worker(DungeonCrawlWeb.Worker, [arg1, arg2, arg3]),
      {DungeonCrawl.DungeonProcesses.DungeonRegistry, name: DungeonInstanceRegistry},
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DungeonCrawl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    DungeonCrawlWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
