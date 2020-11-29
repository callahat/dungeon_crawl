defmodule DungeonCrawl.DungeonProcesses.InstanceProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Admin
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.ProgramRegistry
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.StateValue

  ## Client API

  @timeout 50
  @db_update_timeout 5000

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Sets the instance id
  """
  def set_instance_id(instance, instance_id) do
    GenServer.cast(instance, {:set_instance_id, {instance_id}})
  end

  @doc """
  Sets the map set instance id
  """
  def set_map_set_instance_id(instance, map_set_instance_id) do
    GenServer.cast(instance, {:set_map_set_instance_id, {map_set_instance_id}})
  end

  @doc """
  Sets the level number
  """
  def set_level_number(instance, number) do
    GenServer.cast(instance, {:set_number, {number}})
  end

  @doc """
  Sets the adjacent map instance id for the given direction
  """
  def set_adjacent_map_id(instance, map_instance_id, direction) do
    GenServer.cast(instance, {:set_adjacent_map_id, {map_instance_id, direction}})
  end

  @doc """
  Sets the instance state values
  """
  def set_state_values(instance, state_values) do
    GenServer.cast(instance, {:set_state_values, {state_values}})
  end

  @doc """
  Initializes the dungeon map instance and starts the programs.
  """
  def load_map(instance, map_tiles) do
    map_tiles
    |> Enum.each( fn(map_tile) ->
         GenServer.cast(instance, {:create_map_tile, {map_tile}})
       end )
  end

  @doc """
  Sets spawn points.
  """
  def load_spawn_coordinates(instance, spawn_coordinates) do
    spawn_coordinates
    |> Enum.each( fn(spawn_coordinate) ->
         GenServer.cast(instance, {:create_spawn_coordinate, {spawn_coordinate}})
       end )
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(instance) do
    Process.send_after(instance, :perform_actions, @timeout)
    Process.send_after(instance, :write_db, @db_update_timeout)
  end

  @doc """
  Inspect the state
  """
  def get_state(instance) do
    GenServer.call(instance, {:get_state})
  end

  @doc """
  Check is a tile/program responds to an event
  """
  def responds_to_event?(instance, tile_id, event) do
    GenServer.call(instance, {:responds_to_event?, {tile_id, event}})
  end

  @doc """
  Send an event to a tile/program.
  """
  def send_event(instance, tile_id, event, sender) do
    GenServer.cast(instance, {:send_event, {tile_id, event, sender}})
  end

  @doc """
  Send a standard behavior message to a map tile.
  """
  def send_standard_behavior(instance, tile_id, event, sender) do
    GenServer.cast(instance, {:send_standard_behavior, {tile_id, event, sender}})
  end

  @doc """
  Gets the tile for the given map tile id.
  """
  def get_tile(instance, tile_id) do
    GenServer.call(instance, {:get_map_tile, {tile_id}})
  end

  @doc """
  Gets the tile for the given row, col coordinates. If there are many tiles there,
  the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col) do
    GenServer.call(instance, {:get_map_tile, {row, col}})
  end

  @doc """
  Gets the tile for the given row, col coordinates one away in the given direction.
  If there are many tiles there, the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col, direction) do
    GenServer.call(instance, {:get_map_tile, {row, col, direction}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates.
  """
  def get_tiles(instance, row, col) do
    GenServer.call(instance, {:get_map_tiles, {row, col}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates one away in the given direction.
  """
  def get_tiles(instance, row, col, direction) do
    GenServer.call(instance, {:get_map_tiles, {row, col, direction}})
  end

  @doc """
  Updates the given map_tile.
  """
  def update_tile(instance, tile_id, attrs) do
    GenServer.cast(instance, {:update_map_tile, {tile_id, attrs}})
  end

  @doc """
  Deletes the given map tile.
  """
  def delete_tile(instance, tile_id) do
    GenServer.cast(instance, {:delete_map_tile, {tile_id}})
  end

  @doc """
  Runs the given function in the context of the instance process.
  Expects the function passed in to take one parameter; `instance_state`.
  The function should return a tuple containing the return value for `run_with` and
  the modified state for the first and second tuple members respectively.
  """
  def run_with(instance, func) when is_function(func) do
    GenServer.call(instance, {:run_with, {func}})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, program_registry} = ProgramRegistry.start_link([])
    ProgramRegistry.link_instance(program_registry, self())
    {:ok, %Instances{program_registry: program_registry}}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:responds_to_event?, {tile_id, event}}, _from, %Instances{} = state) do
    true_or_false = Instances.responds_to_event?(state, %{id: tile_id}, event)
    {:reply, true_or_false, state}
  end

  @impl true
  def handle_call({:get_map_tile, {tile_id}}, _from, %Instances{} = state) do
    map_tile = Instances.get_map_tile_by_id(state, %{id: tile_id})
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tile, {row, col}}, _from, state) do
    map_tile = Instances.get_map_tile(state, %{row: row, col: col})
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tile, {row, col, direction}}, _from, state) do
    map_tile = Instances.get_map_tile(state, %{row: row, col: col}, direction)
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tiles, {row, col}}, _from, %Instances{} = state) do
    map_tiles = Instances.get_map_tiles(state, %{row: row, col: col})
    {:reply, map_tiles, state}
  end

  @impl true
  def handle_call({:get_map_tiles, {row, col, direction}}, _from, %Instances{} = state) do
    map_tiles = Instances.get_map_tiles(state, %{row: row, col: col}, direction)
    {:reply, map_tiles, state}
  end

  @impl true
  def handle_call({:run_with, {function}}, _from, %Instances{} = state) when is_function(function) do
    {return_value, state} = function.(state)
    {:reply, return_value, state}
  end

  @impl true
  def handle_cast({:set_instance_id, {instance_id}}, %Instances{} = state) do
    {:noreply, %{ state | instance_id: instance_id }}
  end

  @impl true
  def handle_cast({:set_map_set_instance_id, {map_set_instance_id}}, %Instances{} = state) do
    {:noreply, %{ state | map_set_instance_id: map_set_instance_id }}
  end

  @impl true
  def handle_cast({:set_number, {number}}, %Instances{} = state) do
    {:noreply, %{ state | number: number }}
  end

  @impl true
  def handle_cast({:set_adjacent_map_id, {map_instance_id, direction}}, %Instances{adjacent_map_ids: adjacent_map_ids} = state) do
    {:noreply, %{ state | adjacent_map_ids: Map.put(adjacent_map_ids, direction, map_instance_id) }}
  end

  @impl true
  def handle_cast({:set_state_values, {state_values}}, %Instances{} = state) do
    {:noreply, %{ state | state_values: state_values }}
  end

  @impl true
  def handle_cast({:create_map_tile, {map_tile}}, %Instances{} = state) do
    {_map_tile, state} = Instances.create_map_tile(state, map_tile)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_spawn_coordinate, {spawn_coordinate}}, %Instances{} = state) do
    {:noreply, %{ state | spawn_coordinates: [spawn_coordinate | state.spawn_coordinates] }}
  end

  @impl true
  def handle_cast({:send_event, {tile_id, event, sender}}, %Instances{} = state) do
    state = Instances.send_event(state, %{id: tile_id}, event, sender)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_standard_behavior, {tile_id, event, sender}}, %Instances{} = state) do
    state = _standard_behaviors([ {tile_id, event, sender} ], state)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_map_tile, {tile_id, new_attributes}}, %Instances{} = state) do
    {_updated_tile, state} = Instances.update_map_tile(state, %{id: tile_id}, new_attributes)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_map_tile, {map_tile_id}}, %Instances{} = state) do
    {_deleted_tile, state} = Instances.delete_map_tile(state, %{id: map_tile_id})
    {:noreply, state}
  end

  @impl true
  def handle_info(:perform_actions, %Instances{count_to_idle: 0} = state) do
    ProgramRegistry.pause_all_programs(state.program_registry)

    {:noreply, state}
  end

  def handle_info(:perform_actions, %Instances{} = state) do
    start_ms = :os.system_time(:millisecond)
    state = _rerender_tiles(state)
            |> _check_for_players()
    elapsed_ms = :os.system_time(:millisecond) - start_ms
    if elapsed_ms > @timeout do
      Logger.warn "perform_actions for instance # #{state.instance_id} took #{(:os.system_time(:millisecond) - start_ms)} ms !!!"
    end

    Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, state}
  end

  # TODO: maybe there really isn't any need to write to the DB periodically. It is expensive and not really ever
  # read back. It might be ok to to when all players leave and the processes are being shut down AND the instance
  # is a permanent one. Currently when everyone is out of the instance, the DB and processes for the map set are
  # removed.
  @impl true
  def handle_info(:write_db, %Instances{dirty_ids: dirty_ids, new_ids: new_ids} = state) do
    start_ms = :os.system_time(:millisecond)

    {new_ids, ids_to_persist} = new_ids
                                |> Map.to_list
                                |> Enum.map(fn({new_id, age}) -> {new_id, age + 1} end)
                                |> Enum.split_with(fn({_, age}) -> age < 2 end)

    # TODO: maybe cap the number of ids to persist, put the excess back on the new_ids list
    state = ids_to_persist
            |> Enum.map(fn({id, _}) -> id end)
            |> Enum.reduce(state, fn(temp_id, state) ->
                 map_tile = Instances.get_map_tile_by_id(state, %{id: temp_id})
                            |> Map.put(:id, nil)
                            |> DungeonCrawl.Repo.insert!()
                 Instances.set_map_tile_id(state, map_tile, temp_id)
               end)

    myself = self()

    # save off this other stuff but don't block the GenServer, and dont care about the result
    Task.start(fn ->
      # :deleted
      # :updated
      [deletes, updates] = dirty_ids
                           |> Map.to_list
                           |> Enum.filter(fn({id, _}) -> is_integer(id) end) # filter out new_x tiles - these dont yet exist in the db
                           |> Enum.split_with(fn({_, event}) -> event == :deleted end)
                           |> Tuple.to_list()
                           |> Enum.map(fn(items) ->
                                Enum.map(items, fn({id,_}) -> id end)
                              end)

      updates = updates -- deletes

      if deletes != [] do
        deletes |> DungeonInstances.delete_map_tiles()
      end

      if updates != [] do
        updates
        |> Enum.map(fn(updated_id) ->
             dirty_ids[updated_id]
           end)
        |> DungeonInstances.update_map_tiles()
      end

      Process.send_after(myself, :write_db, @db_update_timeout)

      if :os.system_time(:millisecond) - start_ms > 200 do
        Logger.info "write_db for instance # #{state.instance_id} took #{(:os.system_time(:millisecond) - start_ms)} ms"
      end
    end)

    {:noreply, %Instances{ state | dirty_ids: %{}, new_ids: Enum.into(new_ids, %{})}}
  end

  defp _rerender_tiles(%{ rerender_coords: coords } = state ) when coords == %{}, do: state
  defp _rerender_tiles(state) do
    if length(Map.keys(state.rerender_coords)) > _full_rerender_threshold() do
      dungeon_table = DungeonCrawlWeb.SharedView.dungeon_as_table(state, state.state_values[:rows], state.state_values[:cols])
      DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}",
                                         "full_render",
                                         %{dungeon_render: dungeon_table}
    else
      tile_changes = \
      state.rerender_coords
      |> Map.keys
      |> Enum.map(fn coord ->
           tile = Instances.get_map_tile(state, coord)
           Map.put(coord, :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
         end)
      payload = %{tiles: tile_changes}

      DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{state.instance_id}", "tile_changes", payload)
    end

    %{ state | rerender_coords: %{} }
  end

  defp _check_for_players(state) do
    if state.player_locations != %{}, do:   state,
                                      else: %{ state | count_to_idle: state.count_to_idle - 1 }
  end

  defp _full_rerender_threshold() do
    if threshold = Application.get_env(:dungeon_crawl, :full_rerender_threshold) do
      threshold
    else
      Application.put_env :dungeon_crawl, :full_rerender_threshold, Admin.get_setting().full_rerender_threshold || 50
    end
  end

  defp _standard_behaviors([], state), do: state
  defp _standard_behaviors([ {map_tile_id, label, sender} | messages ], state) do
    case String.downcase(label) do
      "shot" ->
        _destroyable_behavior([ {map_tile_id, label, sender} | messages ], state)
      "bombed" ->
        _destroyable_behavior([ {map_tile_id, label, sender} | messages ], state)
      _ ->
        _standard_behaviors(messages, state)
    end
  end

  defp _destroyable_behavior([ {map_tile_id, _label, sender} | messages ], state) do
    object = Instances.get_map_tile_by_id(state, %{id: map_tile_id})

    cond do
      object && StateValue.get_int(object, :health) ->
        _damaged_tile(object, sender, messages, state)

      object && StateValue.get_bool(object, :destroyable) ->
        _destroyed_tile(object, messages, state)

      true ->
        _standard_behaviors(messages, state)
    end
  end

  defp _damaged_tile(object, sender, messages, state) do
    {_result, state} = Instances.subtract(state, :health, StateValue.get_int(sender, :damage, 0), object.id)

    _standard_behaviors(messages, state)
  end

  defp _destroyed_tile(object, messages, state) do
    {deleted_tile, state} = Instances.delete_map_tile(state, object)

    if deleted_tile do
      top_tile = Instances.get_map_tile(state, deleted_tile)
      payload = %{tiles: [
                   Map.put(Map.take(deleted_tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(top_tile))
                  ]}
      DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}", "tile_changes", payload
    end

    _standard_behaviors(messages, state)
  end
end
