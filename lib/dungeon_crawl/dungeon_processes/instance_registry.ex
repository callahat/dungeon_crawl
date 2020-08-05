defmodule DungeonCrawl.DungeonProcesses.InstanceRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.DungeonProcesses.{Instances,InstanceProcess,Supervisor}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.StateValue

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}` if the instance exists, `:error` otherwise
  """
  def lookup(server, instance_id) do
    GenServer.call(server, {:lookup, instance_id})
  end

  @doc """
  Looks up or creates the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}`.
  """
  def lookup_or_create(server, instance_id) do
    case GenServer.call(server, {:lookup, instance_id}) do
      :error ->
        create(server, instance_id)
        GenServer.call(server, {:lookup, instance_id})

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc """
  Ensures there is a instance associated with the given `instance_id` in `server`.
  """
  def create(server, instance_id) do
    GenServer.cast(server, {:create, instance_id})
  end

  @doc """
  A convenience method for setting up state when testing.
  Ensures there is a instance associated with the given `instance_id` in `server`,
  and populates it with the array of dungeon_map_tiles.
  Does not create the instance if there's already one with that `instance_id`.
  If instance_id is nil, an available one will be assigned, and injected into
  all the `dungeon_map_tiles`. Returns the `instance_id`.
  """
  def create(server, instance_id, dungeon_map_tiles, spawn_coordinates \\ [], state_values \\ %{}) do
    GenServer.call(server, {:create, instance_id, dungeon_map_tiles, spawn_coordinates, state_values})
  end

  @doc """
  Stops the instance associated with the given `instance_id` in `server`, allowing it to be removed.
  """
  def remove(server, instance_id) do
    GenServer.cast(server, {:remove, instance_id})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    instance_ids = %{}
    refs = %{}
    {:ok, {instance_ids, refs}}
  end

  @impl true
  def handle_call({:lookup, instance_id}, _from, state) do
    {instance_ids, _} = state
    {:reply, Map.fetch(instance_ids, instance_id), state}
  end

  @impl true
  def handle_call({:create, nil, dungeon_map_tiles, spawn_coordinates, state_values}, _from, {instance_ids, refs}) do
    instance_id = if instance_ids == %{}, do: 0, else: Enum.max(Map.keys(instance_ids)) + 1
    dungeon_map_tiles = Enum.map(dungeon_map_tiles, fn(dmt) -> Map.put(dmt, :map_instance_id, instance_id) end)
    {:reply, instance_id, _create_instance(instance_id, dungeon_map_tiles, spawn_coordinates, state_values, {instance_ids, refs})}
  end

  @impl true
  def handle_call({:create, instance_id, dungeon_map_tiles, spawn_coordinates, state_values}, _from, {instance_ids, refs}) do
    if Map.has_key?(instance_ids, instance_id) do
      {:noreply, {instance_ids, refs}}
    else
      {:reply, instance_id, _create_instance(instance_id, dungeon_map_tiles, spawn_coordinates, state_values, {instance_ids, refs})}
    end
  end

  @impl true
  def handle_cast({:create, instance_id}, {instance_ids, refs}) do
    if Map.has_key?(instance_ids, instance_id) do
      {:noreply, {instance_ids, refs}}
    else
      with dungeon_instance when not is_nil(dungeon_instance) <- DungeonInstances.get_map(instance_id) do
        {:ok, state_values} = StateValue.Parser.parse(dungeon_instance.state)
        state_values = Map.merge(state_values, %{rows: dungeon_instance.height, cols: dungeon_instance.width})
        dungeon_map_tiles = Repo.preload(dungeon_instance, :dungeon_map_tiles).dungeon_map_tiles
        spawn_coordinates = _spawn_coordinates(dungeon_map_tiles, []) # floor tiles for now
        {:noreply, _create_instance(instance_id, dungeon_map_tiles, spawn_coordinates, state_values, {instance_ids, refs})}
      else
        _ -> Logger.error "Got a CREATE cast for #{instance_id} but its already been cleared"
        {:noreply, {instance_ids, refs}}
      end
    end
  end

  @impl true
  def handle_cast({:remove, instance_id}, {instance_ids, refs}) do
    if Map.has_key?(instance_ids, instance_id), do: GenServer.stop(Map.fetch!(instance_ids, instance_id), :shutdown)
    {:noreply, {instance_ids, refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {instance_ids, refs}) do
    {instance_id, refs} = Map.pop(refs, ref)
    instance_ids = Map.delete(instance_ids, instance_id)
    {:noreply, {instance_ids, refs}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp _create_instance(instance_id, dungeon_map_tiles, spawn_coordinates, state_values, {instance_ids, refs}) do
    {:ok, instance_process} = DynamicSupervisor.start_child(Supervisor, InstanceProcess)
    InstanceProcess.set_instance_id(instance_process, instance_id)
    InstanceProcess.set_state_values(instance_process, state_values)
    InstanceProcess.load_map(instance_process, dungeon_map_tiles)
    InstanceProcess.load_spawn_coordinates(instance_process, spawn_coordinates)
    _link_player_locations(instance_process, instance_id)
    InstanceProcess.start_scheduler(instance_process)
    ref = Process.monitor(instance_process)
    refs = Map.put(refs, ref, instance_id)
    instance_ids = Map.put(instance_ids, instance_id, instance_process)
    {instance_ids, refs}
  end

  defp _link_player_locations(instance_process, instance_id) do
    InstanceProcess.run_with(instance_process, fn (instance_state) ->
      {:ok,
        Player.players_in_instance(%DungeonInstances.Map{id: instance_id})
        |> Enum.reduce(instance_state, fn(location, instance_state) ->
             case Instances.get_map_tile_by_id(instance_state, %{id: location.map_tile_instance_id}) do
               nil ->
                 # probably should never get here since all map tiles would have been loaded
                 map_tile = Repo.preload(location, :map_tile).map_tile
                 {_tile, instance_state} = Instances.create_player_map_tile(instance_state, map_tile, location)
                 instance_state

               player_map_tile ->
                 %{ instance_state | player_locations: Map.put(instance_state.player_locations, player_map_tile.id, location)}
             end
           end)
      }
    end)
  end

  defp _spawn_coordinates(dungeon_map_tiles, []) do
    dungeon_map_tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> Enum.reduce(%{}, fn(dmt,acc) -> if Map.has_key?(acc, {dmt.row, dmt.col}), do: acc, else: Map.put(acc, {dmt.row, dmt.col}, dmt) end)
    |> Map.to_list()
    |> Enum.reject(fn({_coords, dmt}) -> dmt.name != "Floor" end)
    |> Enum.map(fn({coords, _dmt}) -> coords end)
  end
end
