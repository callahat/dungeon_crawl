defmodule DungeonCrawl.DungeonProcesses.LevelRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.DungeonProcesses.{Cache,Levels,LevelProcess}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo
  alias DungeonCrawl.StateValue

  @owner_id nil

  defstruct level_numbers: %{},
            refs: %{},
            cache: nil,
            map_set_process: nil,
            supervisor: nil,
            dungeon_instance_id: nil

  alias DungeonCrawl.DungeonProcesses.LevelRegistry

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(msi_pid, opts) do
    GenServer.start_link(__MODULE__, msi_pid, opts)
  end

  @doc """
  Sets the dungeon_instance_id. This will be used along with the level number and player
  location id to create [or lookup] level instances from the DB.

  Returns `:ok`
  """
  def set_dungeon_instance_id(server, dungeon_instance_id) do
    GenServer.call(server, {:set_dungeon_instance_id, dungeon_instance_id})
  end

  @doc """
  Looks up the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, {instance_id, pid}}` if the instance exists, `:error` otherwise
  """
  def lookup(server, level_number) do
    GenServer.call(server, {:lookup, level_number, @owner_id})
  end

  @doc """
  Looks up or creates the instance pid for `instance_number` stored in `server`.

  Returns `{:ok, {instance_id, pid}}`.
  """
  def lookup_or_create(server, level_number) do
    case GenServer.call(server, {:lookup, level_number, @owner_id}) do
      :error ->
        create(server, level_number)
        lookup(server, level_number)

      {:ok, id_and_pid} ->
        {:ok, id_and_pid}
    end
  end

  @doc """
  Ensures there is a instance associated with the given `level` in `server`. `level` can be either a
  level instance, or a level number.
  """
  def create(server, level_number) when is_integer(level_number) do
    GenServer.call(server, {:create, level_number, @owner_id})
  end

  def create(server, level) do
    GenServer.call(server, {:create, level})
  end

  @doc """
  A convenience method for setting up state when testing.
  Ensures there is a instance associated with the given `instance_id` in `server`,
  and populates it with the array of tiles.
  Does not create the instance if there's already one with that `instance_id`.
  If instance_id is nil, an available one will be assigned, and injected into
  all the `tiles`. Returns the `instance_id`.
  """
  def create(server, instance_id, tiles, spawn_coordinates \\ [], state_values \\ %{}, diid \\ nil, number \\ 1, adjacent \\ %{}, author \\ nil) do
    GenServer.call(server, {:create, @owner_id, instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author})
  end

  @doc """
  Stops the instance associated with the given `instance_id` in `server`, allowing it to be removed.
  """
  def remove(server, level_number) do
    GenServer.cast(server, {:remove, level_number, @owner_id})
  end

  @doc """
  List the level numbers to owner ids to instance ids and the instance processes
  they are associated with.
  Gives some insight into what instance processes are running.

  ## Examples

    iex> list(server)
    %{1 => %{123 => {12345, PID<1>},
             234 => {12345, PID<2>}},
      ...}
  """
  def list(server) do
    GenServer.call(server, {:list})
  end

  @doc """
  List the instance ids and the instance processes they are associated with.
  Returns an Enum of tuples, first element is the level instance id,
  second element is the instance process. Unlike `list`, no information
  about level number nor owner is directly returned.

  ## Examples

    iex> flat_list(server)
    [{12345, PID<1>}, {12345, PID<2>}, ...}
  """
  def flat_list(server) do
    GenServer.call(server, {:flat_list})
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
    {:ok, cache_process} = Cache.start_link([])
    {:ok, supervisor} = DynamicSupervisor.start_link strategy: :one_for_one
    level_registry = %LevelRegistry{map_set_process: map_set_process,
                                    supervisor: supervisor,
                                    cache: cache_process}
    {:ok, level_registry}
  end

  @impl true
  def handle_call({:set_dungeon_instance_id, di_id}, _from, level_registry) do
    {:reply, di_id, %{ level_registry | dungeon_instance_id: di_id }}
  end

  @impl true
  def handle_call({:lookup, level_number, owner_id}, _from, %{level_numbers: level_numbers} = level_registry) do
    case Map.fetch(level_numbers, level_number) do
      {:ok, instance_ids} ->
        {:reply, Map.fetch(instance_ids, owner_id), level_registry}
      _ ->
        {:reply, :error, level_registry}
    end
  end

  # These first two are really to make test setup more convenient
  @impl true
  def handle_call({:create, owner_id, nil, tiles, spawn_coordinates, state_values, diid, number, adjacent, author}, _from, %{level_numbers: level_numbers} = level_registry) do
    owner_ids = Map.get(level_numbers, number, %{})
    {instance_id, _} = Map.get(owner_ids, owner_id, {0, nil})
    instance_id = instance_id + 1
    tiles = Enum.map(tiles, fn(t) -> Map.put(t, :level_instance_id, instance_id) end)
    level_params = %{player_location_id: owner_id, number: number, id: instance_id}
    {:reply, instance_id, _create_instance(level_params, tiles, spawn_coordinates, state_values, diid, adjacent, author, level_registry)}
  end

  @impl true
  def handle_call({:create, owner_id, instance_id, tiles, spawn_coordinates, state_values, diid, number, adjacent, author}, _from, %{level_numbers: level_numbers} = level_registry) do
    instance_ids = Map.get(level_numbers, number, %{})
    if Map.has_key?(instance_ids, owner_id) do
      {:reply, :exists, level_registry}
    else
      level_params = %{player_location_id: owner_id, number: number, id: instance_id}
      {:reply, instance_id, _create_instance(level_params, tiles, spawn_coordinates, state_values, diid, adjacent, author, level_registry)}
    end
  end

  @impl true
  def handle_call({:create, number, owner_id}, from, %{dungeon_instance_id: di_id} = level_registry) do
    level_header = DungeonInstances.get_level_header(di_id, number)

    if level_header do
      level = DungeonInstances.find_or_create_level(level_header, owner_id)
      handle_call({:create, level}, from, level_registry)
    else
      Logger.error "Got a CREATE cast for DungeonInstance #{di_id} LevelNumber #{number} but no header matched"
      {:reply, :ok, level_registry}
    end
  end

  @impl true
  def handle_call({:create, level_instance}, _from, %{level_numbers: level_numbers} = level_registry) do
    instance_ids = Map.get(level_numbers, level_instance.number, %{})
    if Map.has_key?(instance_ids, level_instance.player_location_id) do
      {:reply, :ok, level_registry}
    else
      {:ok, state_values} = StateValue.Parser.parse(level_instance.state)
      state_values = Map.merge(state_values, %{rows: level_instance.height, cols: level_instance.width})
      diid = level_instance.dungeon_instance_id
      tiles = Repo.preload(level_instance, :tiles).tiles
      spawn_locations = Repo.preload(level_instance, :spawn_locations).spawn_locations
      spawn_coordinates = _spawn_coordinates(tiles, spawn_locations) # uses floor tiles if there are no spawn coordinates
      adjacent = DungeonInstances.get_adjacent_levels(level_instance)
      author = Repo.preload(level_instance, [dungeon: [dungeon: :user]]).dungeon.dungeon.user
      {:reply, :ok, _create_instance(level_instance, tiles, spawn_coordinates, state_values, diid, adjacent, author, level_registry)}
    end
  end

  @impl true
  def handle_call({:list}, _from, %{level_numbers: level_numbers} = level_registry) do
    {:reply, level_numbers, level_registry}
  end

  @impl true
  def handle_call({:flat_list}, _from, %{level_numbers: level_numbers} = level_registry) do
    {:reply, _flat_list(level_numbers), level_registry}
  end

  @impl true
  def handle_call({:player_location_ids}, _from, %{level_numbers: level_numbers} = level_registry) do
    player_location_ids =
    _flat_list(level_numbers)
    |> Enum.flat_map(fn({_instance_id, instance_process}) ->
      LevelProcess.run_with(instance_process, fn(state) ->
        player_locations = Enum.map(state.player_locations, fn({player_tile_id, location}) ->
                             {location.id, player_tile_id, state.number}
                           end)

        {player_locations, state}
      end)
    end)
    {:reply, player_location_ids, level_registry}
  end

  @impl true
  def handle_cast({:remove, level_number, owner_id}, %{level_numbers: level_numbers} = level_registry) do
    instance_ids = Map.get(level_numbers, level_number, %{})
    if Map.has_key?(instance_ids, owner_id) do
      {_instance_id, instance_process} = Map.fetch!(instance_ids, owner_id)
      GenServer.stop(instance_process, :shutdown)
    end

    {:noreply, level_registry}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{level_numbers: level_numbers, refs: refs} = level_registry) do
    {{level_number, owner_id}, refs} = Map.pop(refs, ref)
    instance_ids = Map.get(level_numbers, level_number, %{})
                   |> Map.delete(owner_id)
    # TODO: maybe add the removal of the level number when instance ids is empty map
    level_numbers = Map.put(level_numbers, level_number, instance_ids)

    {:noreply, %{level_registry | level_numbers: level_numbers, refs: refs}}
  end

  @impl true
  def handle_info(_msg, level_registry) do
    {:noreply, level_registry}
  end

  defp _create_instance(level_instance, tiles, spawn_coordinates, state_values, diid, adjacent, author, level_registry) do
    %{supervisor: supervisor, refs: refs, level_numbers: level_numbers, cache: cache} = level_registry
    {:ok, instance_process} = DynamicSupervisor.start_child(supervisor, LevelProcess)
    LevelProcess.set_instance_id(instance_process, level_instance.id)
    LevelProcess.set_dungeon_instance_id(instance_process, diid)
    LevelProcess.set_level_number(instance_process, level_instance.number)
    LevelProcess.set_player_location_id(instance_process, level_instance.player_location_id)
    LevelProcess.set_author(instance_process, author)
    LevelProcess.set_cache(instance_process, cache)
    LevelProcess.set_state_values(instance_process, state_values)
    LevelProcess.load_level(instance_process, tiles)
    LevelProcess.load_spawn_coordinates(instance_process, spawn_coordinates)
    _link_player_locations(instance_process, level_instance.id)
    LevelProcess.set_adjacent_level_numbers(instance_process, adjacent)

    send(instance_process, :perform_actions)
    send(instance_process, :player_torch_timeout)
    ref = Process.monitor(instance_process)
    refs = Map.put(refs, ref, {level_instance.number, level_instance.player_location_id})

    instance_ids = Map.get(level_numbers, level_instance.number, %{})
                   |> Map.put(level_instance.player_location_id, {level_instance.id, instance_process})

    level_numbers = Map.put(level_numbers, level_instance.number, instance_ids)
    %{ level_registry | level_numbers: level_numbers, refs: refs }
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

  defp _flat_list(level_numbers) do
    Enum.flat_map(level_numbers, fn({_, owners}) ->
      Enum.map(owners, fn {_oid, ids_pids} -> ids_pids end)
    end)
  end
end
