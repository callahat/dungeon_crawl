defmodule DungeonCrawl.Shipping.DockWorker do
  use GenServer

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.{DungeonExports, DungeonImports, Json}

  @timeout 360_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def export(dungeon_export_id) do
    _pool_wrapper({:export, dungeon_export_id})
  end

  def import(dungeon_import_id) do
    _pool_wrapper({:import, dungeon_import_id})
  end

  ## Callbacks

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:export, dungeon_export_id}, _from, state) do
    # export the dungeon, return the dungeon export id
    export = Repo.preload(Shipping.get_export!(dungeon_export_id), :dungeon)

    {:ok, export_json} = DungeonExports.run(export.dungeon_id)
                         |> Jason.encode()

    Shipping.update_export(export,
      %{file_name: _file_name(export.dungeon), data: export_json, status: :completed})

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:import, dungeon_import_id}, _from, state) do
    # import the dungeon, return the created id
    import = Shipping.get_import!(dungeon_import_id)

    import_hash = Json.decode!(import.data)
                  |> DungeonImports.run(import.user_id)

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
            e, r -> IO.inspect("poolboy transaction caught error: #{inspect(e)}, #{inspect(r)}")
                    :ok
          end
        end,
        @timeout
      )
    end)
  end
end