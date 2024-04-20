defmodule DungeonCrawl.Shipping.DockWorker do
  use GenServer

  alias DungeonCrawlWeb.Endpoint
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.{DungeonExports, DungeonImports, Json, Export, Import}

  require Logger

  @timeout 600_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def export(%Export{} = dungeon_export, worker_timeout \\ @timeout) do
    _pool_wrapper({:export, dungeon_export}, worker_timeout)
  end

  def import(%Import{} = dungeon_import, worker_timeout \\ @timeout) do
    _pool_wrapper({:import, dungeon_import}, worker_timeout)
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
    _broadcast_status({:export, export})

    export_json = DungeonExports.run(export.dungeon_id)
                  |> Json.encode!()

    Shipping.update_export(export,
      %{file_name: _file_name(export.dungeon), data: export_json, status: :completed})
    _broadcast_status({:export, export})

    {:reply, :ok, state}
  end

  @log_order %{
    "?" => 1,
    "x" => 2,
    "u" => 3,
    "+" => 4,
    "." => 5,
    "r" => 8,
    "=" => 9
  }

  @impl true
  def handle_call({:import, import}, _from, state) do
    # import the dungeon, return the created id
    {:ok, import} = Shipping.update_import(import, %{status: :running,  details: nil})
    _broadcast_status({:import, import})

    user = DungeonCrawl.Repo.preload(import, :user).user

    import_hash = Json.decode!(import.data)
                  |> DungeonImports.run(user, import.id, import.line_identifier)

    [end_line | log] = import_hash.log
    [start_line | log] = Enum.reverse(log)
    log = Enum.sort(log, fn a,b ->
            (@log_order[String.at(a,0)] || 0) <
              (@log_order[String.at(b,0)] || 0)
          end)

    import_log = Enum.join([start_line | log], "\n") <>
                 "\n#{ end_line }" <>
                 "\n---------------\n" <>
                 import.log

    attrs = if import_hash.status == "done",
               do: %{dungeon_id: import_hash.dungeon.id, status: :completed, details: nil, log: import_log},
               else: %{status: :waiting, details: "waiting on user choices", log: import_log}

    Shipping.update_import(import, attrs)
    _broadcast_status({:import, import})

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

  defp _pool_wrapper({_, record} = params, worker_timeout) do
    Task.async(fn ->
      :poolboy.transaction(
        :dock_worker,
        fn dock_worker ->
          Logger.info("*** Starting worker for: #{ inspect params }")
          try do
            GenServer.call(dock_worker, params, worker_timeout)
            Logger.info("*** Worker done for: #{ inspect params }")
          catch
            code, error ->
              Shipping.update(record, %{status: :failed, details: _readable_error(error)})
              _broadcast_status("error", params)
              Logger.warning("poolboy transaction caught error: #{inspect(code)}, #{inspect(error)}")
              Process.exit(dock_worker, :kill) # make sure its dead, esp on a timeout
              :ok
          end
        end,
        @timeout
      )
    end)
  end

  defp _broadcast_status(params) do
    _broadcast_status("refresh_status", params)
  end

  defp _broadcast_status(type, {import_or_export, record}) do
    Endpoint.broadcast("#{ import_or_export }_status_#{record.user_id}", type, nil)
    Endpoint.broadcast("#{ import_or_export }_status", type, nil)
  end

  defp _readable_error({:timeout, _}) do
    "took too long"
  end

  defp _readable_error({{error = %Ecto.NoResultsError{}, _}, _}) do
    case Regex.named_captures(~r/in DungeonCrawl\..*?\.(?<class>.*?),.*?slug == \^\"(?<slug>.*?)\"/s, error.message) do
      %{"class" => class, "slug" => slug} ->
        "could not find a #{ class } with slug '#{ slug }' that was referenced in a script or starting equipment"
      _ ->
        "could not find a slug that was referenced in a script or starting equipment"
    end
  end

  defp _readable_error({{%Jason.DecodeError{}, _}, _}) do
    "error parsing JSON"
  end

  defp _readable_error(_) do
    "a problem occurred"
  end
end
