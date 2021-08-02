defmodule DungeonCrawl.DungeonProcesses.LevelRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.DungeonProcesses.{Levels,LevelProcess}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.StateValue

  defstruct instance_ids: %{}, refs: %{}, map_set_process: nil, supervisor: nil

  alias DungeonCrawl.DungeonProcesses.LevelRegistry

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(msi_pid, opts) do
    GenServer.start_link(__MODULE__, msi_pid, opts)
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
        lookup(server, instance_id)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc """
  Ensures there is a instance associated with the given `instance_id` in `server`.
  """
  def create(server, instance_id) when is_integer(instance_id) do
    with level_instance when not is_nil(level_instance) <- DungeonInstances.get_level(instance_id) do
      create(server, level_instance)
    else
      _error ->
        Logger.error "Got a CREATE cast for #{instance_id} but its already been cleared"
        nil
    end
  end

  def create(server, level_instance) do
    GenServer.call(server, {:create, level_instance})
  end

  @doc """
  A convenience method for setting up state when testing.
  Ensures there is a instance associated with the given `instance_id` in `server`,
  and populates it with the array of tiles.
  Does not create the instance if there's already one with that `instance_id`.
  If instance_id is nil, an available one will be assigned, and injected into
  all the `tiles`. Returns the `instance_id`.
  """
  def create(server, instance_id, tiles, spawn_coordinates \\ [], state_values \\ %{}, diid \\ nil, number \\ nil, adjacent \\ %{}, author \\ nil) do
    GenServer.call(server, {:create, instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author})
  end

  @doc """
  Stops the instance associated with the given `instance_id` in `server`, allowing it to be removed.
  """
  def remove(server, instance_id) do
    GenServer.cast(server, {:remove, instance_id})
  end

  @doc """
  List the instance ids and the instance processes they are associated with.
  Gives some insight into what instance processes are running.
  """
  def list(server) do
    GenServer.call(server, {:list})
  end

  @doc """
  Returns an enum of tuples containing the location_id and tile_instance_id for all the players in the dungeon instance
  """
  def player_location_ids(server) do
    GenServer.call(server, {:player_location_ids})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(map_set_process) do
    Process.flag(:trap_exit, true)
    {:ok, supervisor} = DynamicSupervisor.start_link strategy: :one_for_one
    level_registry = %LevelRegistry{map_set_process: map_set_process, supervisor: supervisor}
    {:ok, level_registry}
  end

  @impl true
  def handle_call({:lookup, instance_id}, _from, %{instance_ids: instance_ids} = level_registry) do
    {:reply, Map.fetch(instance_ids, instance_id), level_registry}
  end

  # These first two are really to make test setup more convenient
  @impl true
  def handle_call({:create, nil, tiles, spawn_coordinates, state_values, diid, number, adjacent, author}, _from, %{instance_ids: instance_ids} = level_registry) do
    instance_id = if instance_ids == %{}, do: 0, else: Enum.max(Map.keys(instance_ids)) + 1
    tiles = Enum.map(tiles, fn(t) -> Map.put(t, :level_instance_id, instance_id) end)
    {:reply, instance_id, _create_instance(instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author, level_registry)}
  end

  @impl true
  def handle_call({:create, instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author}, _from, %{instance_ids: instance_ids} = level_registry) do
    if Map.has_key?(instance_ids, instance_id) do
      {:noreply, level_registry}
    else
      {:reply, instance_id, _create_instance(instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author, level_registry)}
    end
  end

  @impl true
  def handle_call({:create, level_instance}, _from, %{instance_ids: instance_ids} = level_registry) do
    if Map.has_key?(instance_ids, level_instance.id) do
      {:reply, :ok, level_registry}
    else
      {:ok, state_values} = StateValue.Parser.parse(level_instance.state)
      state_values = Map.merge(state_values, %{rows: level_instance.height, cols: level_instance.width})
      diid = level_instance.dungeon_instance_id
      number = level_instance.number
      tiles = Repo.preload(level_instance, :tiles).tiles
      spawn_locations = Repo.preload(level_instance, :spawn_locations).spawn_locations
      spawn_coordinates = _spawn_coordinates(tiles, spawn_locations) # uses floor tiles if there are no spawn coordinates
      adjacent = DungeonInstances.get_adjacent_levels(level_instance)
      author = Repo.preload(level_instance, [dungeon: [dungeon: :user]]).dungeon.dungeon.user
      {:reply, :ok, _create_instance(level_instance.id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author, level_registry)}
    end
  end

  @impl true
  def handle_call({:list}, _from, %{instance_ids: instance_ids} = level_registry) do
    {:reply, instance_ids, level_registry}
  end

  @impl true
  def handle_call({:player_location_ids}, _from, %{instance_ids: instance_ids} = level_registry) do
    player_location_ids = \
    instance_ids
    |> Enum.flat_map(fn({_instance_id, instance_process}) ->
         LevelProcess.run_with(instance_process, fn(state) ->
           player_locations = \
           state.player_locations
           |> Enum.map(fn({player_tile_id, location}) ->
                {location.id, player_tile_id, state.number}
              end)

           {player_locations, state}
         end)
       end)
    {:reply, player_location_ids, level_registry}
  end

  @impl true
  def handle_cast({:remove, instance_id}, %{instance_ids: instance_ids} = level_registry) do
    if Map.has_key?(instance_ids, instance_id), do: GenServer.stop(Map.fetch!(instance_ids, instance_id), :shutdown)
    {:noreply, level_registry}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{instance_ids: instance_ids, refs: refs} = level_registry) do
    {instance_id, refs} = Map.pop(refs, ref)
    instance_ids = Map.delete(instance_ids, instance_id)
    {:noreply, %{level_registry | instance_ids: instance_ids, refs: refs}}
  end

  @impl true
  def handle_info(_msg, level_registry) do
    {:noreply, level_registry}
  end

  defp _create_instance(instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author, level_registry) do
    %{supervisor: supervisor, refs: refs, instance_ids: instance_ids} = level_registry
    {:ok, instance_process} = DynamicSupervisor.start_child(supervisor, LevelProcess)
    LevelProcess.set_instance_id(instance_process, instance_id)
    LevelProcess.set_dungeon_instance_id(instance_process, diid)
    LevelProcess.set_level_number(instance_process, number)
    LevelProcess.set_author(instance_process, author)
    LevelProcess.set_state_values(instance_process, state_values)
    LevelProcess.load_level(instance_process, tiles)
    LevelProcess.load_spawn_coordinates(instance_process, spawn_coordinates)
    _link_player_locations(instance_process, instance_id)
    if adjacent["north"], do: LevelProcess.set_adjacent_level_id(instance_process, adjacent["north"].id, "north")
    if adjacent["south"], do: LevelProcess.set_adjacent_level_id(instance_process, adjacent["south"].id, "south")
    if adjacent["east"], do: LevelProcess.set_adjacent_level_id(instance_process, adjacent["east"].id, "east")
    if adjacent["west"], do: LevelProcess.set_adjacent_level_id(instance_process, adjacent["west"].id, "west")

    send(instance_process, :perform_actions)
    ref = Process.monitor(instance_process)
    refs = Map.put(refs, ref, instance_id)
    instance_ids = Map.put(instance_ids, instance_id, instance_process)
    %{ level_registry | instance_ids: instance_ids, refs: refs }
  end

  defp _link_player_locations(instance_process, instance_id) do
    LevelProcess.run_with(instance_process, fn (instance_state) ->
      {:ok,
        Player.players_in_instance(%DungeonInstances.Level{id: instance_id})
        |> Enum.reduce(instance_state, fn(location, instance_state) ->
             case Levels.get_tile_by_id(instance_state, %{id: location.tile_instance_id}) do
               nil ->
                 # probably should never get here since all tiles would have been loaded
                 tile = Repo.preload(location, :tile).tile
                 {_tile, instance_state} = Levels.create_player_tile(instance_state, tile, location)
                 instance_state

               player_tile ->
                 %{ instance_state | player_locations: Map.put(instance_state.player_locations, player_tile.id, location)}
             end
           end)
      }
    end)
  end

  defp _spawn_coordinates(tiles, []) do
    tiles
    |> Enum.sort(fn(a,b) -> a.z_index > b.z_index end)
    |> Enum.reduce(%{}, fn(t,acc) -> if Map.has_key?(acc, {t.row, t.col}), do: acc, else: Map.put(acc, {t.row, t.col}, t) end)
    |> Map.to_list()
    |> Enum.reject(fn({_coords, t}) -> t.name != "Floor" end)
    |> Enum.map(fn({coords, _t}) -> coords end)
  end

  defp _spawn_coordinates(_tiles, spawn_locations) do
    spawn_locations
    |> Enum.map(fn(spawn_location) -> {spawn_location.row, spawn_location.col} end)
  end
end
