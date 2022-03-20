defmodule DungeonCrawl.Shipping.DockWorker do
  use GenServer

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.{DungeonExports, DungeonImports, Json, Export, Import}

  require Logger

  @timeout 360_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def export(%Export{} = dungeon_export) do
    _pool_wrapper({:export, dungeon_export})
  end

  def import(%Import{} = dungeon_import) do
    _pool_wrapper({:import, dungeon_import})
  end

  ## Callbacks

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:export, export}, _from, state) do
    # export the dungeon, return the dungeon export id
    export = Repo.preload(export, :dungeon)
    {:ok, _} = Shipping.update_export(export, %{status: :running})

    export_json = DungeonExports.run(export.dungeon_id)
                  |> Json.encode!()

    Shipping.update_export(export,
      %{file_name: _file_name(export.dungeon), data: export_json, status: :completed})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:import, import}, _from, state) do
    # import the dungeon, return the created id
    {:ok, _} = Shipping.update_import(import, %{status: :running})

    import_hash = Json.decode!(import.data)
                  |> DungeonImports.run(import.user_id, import.line_identifier)

    Shipping.update_import(import,
      %{dungeon_id: import_hash.dungeon.id, status: :completed})

    {:reply, :ok, state}
  end

  defp _file_name(dungeon) do
    version = "#{dungeon.version}"
    extra = cond do
      dungeon.deleted_at -> "_deleted"
      ! dungeon.active -> "_inactive"
      true -> ""
    end
    String.replace("#{dungeon.name}_v_#{version}#{extra}.json", ~r/\s+/, "_")
  end

  defp _pool_wrapper(params) do
    Task.async(fn ->
      :poolboy.transaction(
        :dock_worker,
        fn dock_worker ->
          try do
            GenServer.call(dock_worker, params)
          catch
            e, r -> Logger.warn("poolboy transaction caught error: #{inspect(e)}, #{inspect(r)}")
                    :ok
          end
        end,
        @timeout
      )
    end)
  end
end