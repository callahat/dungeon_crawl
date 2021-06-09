defmodule DungeonCrawl.DungeonProcesses.LevelProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Account
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.DungeonProcesses.Render
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.StateValue

  ## Client API

  @timeout 50
  @inactive_player_timeout 60_000

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
  Sets the dungeon instance id
  """
  def set_dungeon_instance_id(instance, dungeon_instance_id) do
    GenServer.cast(instance, {:set_dungeon_instance_id, {dungeon_instance_id}})
  end

  @doc """
  Sets the author
  """
  def set_author(instance, author) do
    GenServer.cast(instance, {:set_author, author})
  end

  @doc """
  Sets the level number
  """
  def set_level_number(instance, number) do
    GenServer.cast(instance, {:set_number, {number}})
  end

  @doc """
  Sets the adjacent level instance id for the given direction
  """
  def set_adjacent_level_id(instance, level_instance_id, direction) do
    GenServer.cast(instance, {:set_adjacent_level_id, {level_instance_id, direction}})
  end

  @doc """
  Sets the instance state values
  """
  def set_state_values(instance, state_values) do
    GenServer.cast(instance, {:set_state_values, {state_values}})
  end

  @doc """
  Initializes the level level instance and starts the programs.
  """
  def load_level(instance, tiles) do
    tiles
    |> Enum.each( fn(tile) ->
         GenServer.cast(instance, {:create_tile, {tile}})
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
    Process.send_after(instance, :check_on_inactive_players, @inactive_player_timeout)
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
  Send an event to a tile/program, or all running programs when no tile_id is given.
  If a tile_id is given, the sender must be a player.
  """
  def send_event(instance, event, sender) do
    GenServer.cast(instance, {:send_event, {event, sender}})
  end

  def send_event(instance, tile_id, event, sender) do
    GenServer.cast(instance, {:send_event, {tile_id, event, sender}})
  end

  @doc """
  Gets the tile for the given tile id.
  """
  def get_tile(instance, tile_id) do
    GenServer.call(instance, {:get_tile, {tile_id}})
  end

  @doc """
  Gets the tile for the given row, col coordinates. If there are many tiles there,
  the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col) do
    GenServer.call(instance, {:get_tile, {row, col}})
  end

  @doc """
  Gets the tile for the given row, col coordinates one away in the given direction.
  If there are many tiles there, the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col, direction) do
    GenServer.call(instance, {:get_tile, {row, col, direction}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates.
  """
  def get_tiles(instance, row, col) do
    GenServer.call(instance, {:get_tiles, {row, col}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates one away in the given direction.
  """
  def get_tiles(instance, row, col, direction) do
    GenServer.call(instance, {:get_tiles, {row, col, direction}})
  end

  @doc """
  Updates the given tile.
  """
  def update_tile(instance, tile_id, attrs) do
    GenServer.cast(instance, {:update_tile, {tile_id, attrs}})
  end

  @doc """
  Deletes the given tile.
  """
  def delete_tile(instance, tile_id) do
    GenServer.cast(instance, {:delete_tile, {tile_id}})
  end

  @doc """
  Triggers the end game condition for all players in the instance.
  """
  def gameover(instance, victory, result, instances_module \\ Levels) do
    GenServer.cast(instance, {:gameover, {victory, result, instances_module}})
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
    {:ok, %Levels{}}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:responds_to_event?, {tile_id, event}}, _from, %Levels{} = state) do
    true_or_false = Levels.responds_to_event?(state, %{id: tile_id}, event)
    {:reply, true_or_false, state}
  end

  @impl true
  def handle_call({:get_tile, {tile_id}}, _from, %Levels{} = state) do
    tile = Levels.get_tile_by_id(state, %{id: tile_id})
    {:reply, tile, state}
  end

  @impl true
  def handle_call({:get_tile, {row, col}}, _from, state) do
    tile = Levels.get_tile(state, %{row: row, col: col})
    {:reply, tile, state}
  end

  @impl true
  def handle_call({:get_tile, {row, col, direction}}, _from, state) do
    tile = Levels.get_tile(state, %{row: row, col: col}, direction)
    {:reply, tile, state}
  end

  @impl true
  def handle_call({:get_tiles, {row, col}}, _from, %Levels{} = state) do
    tiles = Levels.get_tiles(state, %{row: row, col: col})
    {:reply, tiles, state}
  end

  @impl true
  def handle_call({:get_tiles, {row, col, direction}}, _from, %Levels{} = state) do
    tiles = Levels.get_tiles(state, %{row: row, col: col}, direction)
    {:reply, tiles, state}
  end

  @impl true
  def handle_call({:run_with, {function}}, _from, %Levels{} = state) when is_function(function) do
    {return_value, state} = function.(state)
    {:reply, return_value, state}
  end

  @impl true
  def handle_cast({:set_instance_id, {instance_id}}, %Levels{} = state) do
    {:noreply, %{ state | instance_id: instance_id }}
  end

  @impl true
  def handle_cast({:set_dungeon_instance_id, {dungeon_instance_id}}, %Levels{} = state) do
    {:noreply, %{ state | dungeon_instance_id: dungeon_instance_id }}
  end

  @impl true
  def handle_cast({:set_number, {number}}, %Levels{} = state) do
    {:noreply, %{ state | number: number }}
  end

  @impl true
  def handle_cast({:set_author, author}, %Levels{} = state) do
    {:noreply, %{ state | author: author }}
  end

  @impl true
  def handle_cast({:set_adjacent_level_id, {level_instance_id, direction}}, %Levels{adjacent_level_ids: adjacent_level_ids} = state) do
    {:noreply, %{ state | adjacent_level_ids: Map.put(adjacent_level_ids, direction, level_instance_id) }}
  end

  @impl true
  def handle_cast({:set_state_values, {state_values}}, %Levels{} = state) do
    {:noreply, %{ state | state_values: state_values }}
  end

  @impl true
  def handle_cast({:create_tile, {tile}}, %Levels{} = state) do
    {_tile, state} = Levels.create_tile(state, tile)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_spawn_coordinate, {spawn_coordinate}}, %Levels{} = state) do
    {:noreply, %{ state | spawn_coordinates: [spawn_coordinate | state.spawn_coordinates] }}
  end

  @impl true
  def handle_cast({:send_event, {event, sender}}, %Levels{} = state) do
    state = state.program_contexts
            |> Enum.reduce(state, fn({po_id, _}, state) -> Levels.send_event(state, po_id, event, sender) end)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_event, {tile_id, event, %DungeonCrawl.Player.Location{} = sender}}, %Levels{} = state) do
    state = Levels.send_event(state, %{id: tile_id}, event, sender)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_tile, {tile_id, new_attributes}}, %Levels{} = state) do
    {_updated_tile, state} = Levels.update_tile(state, %{id: tile_id}, new_attributes)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_tile, {tile_id}}, %Levels{} = state) do
    {_deleted_tile, state} = Levels.delete_tile(state, %{id: tile_id})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:gameover, {victory, result, instances_module}}, %Levels{} = state) do
    {:noreply, instances_module.gameover(state, victory, result)}
  end

  @impl true
  def handle_info(:perform_actions, %Levels{count_to_idle: 0} = state) do
    # No player is here, so don't cycle programs and wait longer til the next cycle, and save off any changes/new tiles
    send(self(), :write_db)

    Process.send_after(self(), :perform_actions, @timeout * 10)

    {:noreply, state}
  end

  @impl true
  def handle_info(:perform_actions, %Levels{} = state) do
    start_ms = :os.system_time(:millisecond)
    state = _cycle_programs(%{state | new_pids: []})
            |> _broadcast_stat_updates()
            |> Render.rerender_tiles()
            |> Render.rerender_tiles_for_admin()
            |> Map.put(:rerender_coords, %{})
            |> _check_for_players()
    elapsed_ms = :os.system_time(:millisecond) - start_ms
    if elapsed_ms > @timeout do
      Logger.warn "_cycle_programs for instance # #{state.instance_id} took #{(:os.system_time(:millisecond) - start_ms)} ms !!!"
    end

    Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, state}
  end

  @impl true
  def handle_info(:check_on_inactive_players, %Levels{inactive_players: inactive_players} = state) do
    {stone, inactive_players} = inactive_players
                                |> Map.to_list()
                                |> Enum.map(fn {tile_id, count} -> {tile_id, count + 1} end)
                                |> Enum.split_with(fn {_, count} -> count > 5 end)

    inactive_players = Enum.into(inactive_players, %{})
    stone = Enum.map(stone, fn {stone_id, _} -> stone_id end)

    Process.send_after(self(), :check_on_inactive_players, @inactive_player_timeout)

    _petrify_old_inactive_players(stone, %{ state | inactive_players: inactive_players})
  end

  # TODO: maybe there really isn't any need to write to the DB periodically. It is expensive and not really ever
  # read back. It might be ok to to when all players leave and the processes are being shut down AND the instance
  # is a permanent one. Currently when everyone is out of the instance, the DB and processes for the map set are
  # removed.
  @impl true
  def handle_info(:write_db, %Levels{dirty_ids: dirty_ids, new_ids: new_ids} = state) do
    start_ms = :os.system_time(:millisecond)

    {new_ids, ids_to_persist} = new_ids
                                |> Map.to_list
                                |> Enum.map(fn({new_id, age}) -> {new_id, age + 1} end)
                                |> Enum.split_with(fn({_, age}) -> age < 2 end)

    # TODO: maybe cap the number of ids to persist, put the excess back on the new_ids list
    state = ids_to_persist
            |> Enum.map(fn({id, _}) -> id end)
            |> Enum.reduce(state, fn(temp_id, state) ->
                 tile = Levels.get_tile_by_id(state, %{id: temp_id})
                            |> Map.put(:id, nil)
                            |> DungeonCrawl.Repo.insert!()
                 Levels.set_tile_id(state, tile, temp_id)
               end)

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
        deletes |> DungeonInstances.delete_tiles()
      end

      if updates != [] do
        updates
        |> Enum.map(fn(updated_id) ->
             dirty_ids[updated_id]
           end)
        |> DungeonInstances.update_tiles()
      end

      if :os.system_time(:millisecond) - start_ms > 200 do
        Logger.info "write_db for instance # #{state.instance_id} took #{(:os.system_time(:millisecond) - start_ms)} ms"
      end
    end)

    {:noreply, %Levels{ state | dirty_ids: %{}, new_ids: Enum.into(new_ids, %{})}}
  end

  # TODO: move these private functions to a new module and make them public so tests can isolate behaviors.
  #Cycles through all the programs, running each until a wait point. Any messages for broadcast or a single player
  #will be broadcast. Typically this will only be called by the scheduler.
  # state is passed in mainly so the map can be updated, the program_contexts in state are updated outside.
  defp _cycle_programs(%Levels{} = state) do
    {program_contexts, state} = state.program_contexts
                                |> Enum.flat_map(fn({k,v}) -> [[k,v]] end)
                                |> _cycle_programs(state)
    # Merge the existing program_contexts with whatever new programs were spawned
    program_contexts = Map.new(program_contexts, fn [k,v] -> {k,v} end)
                       |> Map.merge(Map.take(state.program_contexts, state.new_pids))
    _standard_behaviors(state.program_messages, %{ state | program_contexts: program_contexts })
    |> _message_programs()
  end

  defp _cycle_programs([], state), do: {[], state}
  defp _cycle_programs([[pid, program_context] | program_contexts], state) do
    runner_state = Scripting.Runner.run(%Runner{program: program_context.program, object_id: program_context.object_id, state: state})
                              |> Map.put(:event_sender, program_context.event_sender) # This might not be needed
                              |> Levels.handle_broadcasting() # any nontile_update broadcasts left
    {other_program_contexts, updated_state} = _cycle_programs(program_contexts, runner_state.state)

    if runner_state.program.status == :dead do
      { other_program_contexts, updated_state}
    else
      {[ [pid, Map.take(runner_state, [:program, :object_id, :event_sender])] | other_program_contexts ], updated_state}
    end
  end

  defp _broadcast_stat_updates(%{ dirty_player_tile_stats: pmt_ids} = state) do
    Enum.uniq(pmt_ids)
    |> _broadcast_stat_updates(%{ state | dirty_player_tile_stats: [] })
  end
  defp _broadcast_stat_updates([], state), do: state
  defp _broadcast_stat_updates([ pmt_id | pmt_ids ], state) do
    if player_location = state.player_locations[pmt_id] do
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                         "stat_update",
                                         %{stats: PlayerInstance.current_stats(state, %{id: pmt_id})}
    end
    _broadcast_stat_updates(pmt_ids, state)
  end


  defp _check_for_players(state) do
    if state.player_locations != %{}, do:   state,
                                      else: %{ state | count_to_idle: state.count_to_idle - 1 }
  end

  defp _message_programs(state) do
    program_contexts = state.program_messages
                       |> _message_programs(state.program_contexts)
    %{state | program_contexts: program_contexts, program_messages: []}
  end
  defp _message_programs([], program_contexts), do: program_contexts
  defp _message_programs([ {po_id, label, sender} | messages], program_contexts) do
    program_context = program_contexts[po_id]
    if program_context do
      program = program_context.program
      _message_programs(messages, %{ program_contexts | po_id => %{ program_context | program: Program.send_message(program, label, sender),
                                                                    event_sender: sender}})
    else
      _message_programs(messages, program_contexts)
    end
  end

  defp _petrify_old_inactive_players([], state), do: {:noreply, state}
  defp _petrify_old_inactive_players([tile_id | to_stone], state) do
    if player_location = Levels.get_player_location(state, %{id: tile_id}) do
      player_name = Account.get_name(player_location.user_id_hash)
      Logger.info "Player #{player_name} has idled out and become a statue in MSI #{state.dungeon_instance_id}"
      {_statue, state} = PlayerInstance.petrify(state, %{id: tile_id})
      _petrify_old_inactive_players(to_stone, state)
    else
       Logger.info "Player ID #{tile_id} has idled out but they were not found in MSI #{state.dungeon_instance_id}"
      _petrify_old_inactive_players(to_stone, state)
    end
  end

  defp _standard_behaviors([], state), do: state
  defp _standard_behaviors([ {tile_id, label, sender} | messages ], state) do
    case String.downcase(label) do
      "shot" ->
        _destroyable_behavior([ {tile_id, label, sender} | messages ], state)
      "bombed" ->
        _destroyable_behavior([ {tile_id, label, sender} | messages ], state)
      _ ->
        _standard_behaviors(messages, state)
    end
  end

  defp _destroyable_behavior([ {tile_id, _label, sender} | messages ], state) do
    object = Levels.get_tile_by_id(state, %{id: tile_id})

    cond do
      object && StateValue.get_int(object, :health) ->
        _damaged_tile(object, sender, messages, state)

      object && StateValue.get_bool(object, :destroyable) ->
        _destroyed_tile(object, sender, messages, state)

      true ->
        _standard_behaviors(messages, state)
    end
  end

  defp _damaged_tile(object, sender, messages, state) do
    {result, state} = Levels.subtract(state, :health, StateValue.get_int(sender, :damage, 0), object.id)

    state = if result == :died, do: _award_points(object, sender, state), else: state

    _standard_behaviors(messages, state)
  end

  defp _destroyed_tile(object, sender, messages, state) do
    {deleted_tile, state} = Levels.delete_tile(state, object)

    if deleted_tile do
      state = _award_points(object, sender, state)

      top_tile = Levels.get_tile(state, deleted_tile)
      payload = %{tiles: [
                   Map.put(Map.take(deleted_tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(top_tile))
                  ]}
      DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.dungeon_instance_id}:#{state.instance_id}", "tile_changes", payload
      _standard_behaviors(messages, state)
    else
      _standard_behaviors(messages, state)
    end
  end

  defp _award_points(object, sender, state) do
    awardee = case sender do
                %{parsed_state: %{owner: owner_id}} -> Levels.get_tile_by_id(state, %{id: owner_id})
                %{tile_id: id} -> Levels.get_tile_by_id(state, %{id: id})
                _ -> nil
              end

    points = object.parsed_state[:points]

    if is_number(points) && awardee do
      current_points = awardee.parsed_state[:score] || 0
      {_awardee, state} = Levels.update_tile_state(state, awardee, %{score: current_points + points})

      state
    else
      state
    end
  end
end
