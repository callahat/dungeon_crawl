defmodule DungeonCrawl.DungeonProcesses.Instances do
  @moduledoc """
  The instances context.
  It wraps the retrival and changes of %Instances{}
  """

  @count_to_idle 5

  defstruct instance_id: nil,
            map_set_instance_id: nil,
            number: 0,
            state_values: %{},
            map_by_ids: %{},
            map_by_coords: %{},
            dirty_ids: %{},
            new_ids: %{},
            new_id_counter: 0,
            player_locations: %{},
            spawn_coordinates: [],
            passage_exits: [],
            message_actions: %{}, # todo: this will probably be moved to the program process
            adjacent_map_ids: %{},
            rerender_coords: %{},
            count_to_idle: @count_to_idle,
            program_registry: nil

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonProcesses.ProgramRegistry
  alias DungeonCrawl.DungeonProcesses.ProgramProcess
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.Scripting.Direction

  require Logger

  @doc """
  Returns the top map tile in the given directon from the provided coordinates.
  """
  def get_map_tile(state, %{row: row, col: col} = _map_tile, direction) do
    {d_row, d_col} = Direction.delta(direction)
    get_map_tile(state, %{row: row + d_row, col: col + d_col})
  end
  def get_map_tile(_,_,_), do: nil

  def get_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = _state, %{row: row, col: col} = _map_tile) do
    with tiles when is_map(tiles) <- by_coords[{row, col}],
         [{_z_index, top_tile}] <- Map.to_list(tiles)
                                   |> Enum.sort(fn({a,_},{b,_}) -> a > b end)
                                   |> Enum.take(1) do
      by_id[top_tile]
    else
      _ ->
        nil
    end
  end
  def get_map_tile(_,_), do: nil

  @doc """
  Returns the map tiles in the given directon from the provided coordinates.
  """
  def get_map_tiles(%Instances{} = state, %{row: row, col: col} = _map_tile, direction) do
    {d_row, d_col} = Direction.delta(direction)
    Instances.get_map_tiles(state, %{row: row + d_row, col: col + d_col})
  end
  def get_map_tiles(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = _state, %{row: row, col: col} = _map_tile) do
    with tiles when is_map(tiles) <- by_coords[{row, col}],
         tiles <- Map.to_list(tiles)
                  |> Enum.sort(fn({a,_},{b,_}) -> a > b end)
                  |> Enum.map(fn({_, tile_id}) -> by_id[tile_id] end) do
      tiles
    else
      _ ->
        []
    end
  end

  @doc """
  Gets the map tile given by the id.
  """
  def get_map_tile_by_id(%Instances{map_by_ids: by_id} = _state, %{id: map_tile_id} = _map_tile) do
    by_id[map_tile_id]
  end

  @doc """
  Gets the player location, returns nil if one is not found. Uses a map with an `id` key to lookup based on the map tile
  associated with that location. Otherwise lookup is done based on user_id_hash when the parameter is a binary.
  """
  def get_player_location(%Instances{player_locations: player_locations} = _state, %{id: map_tile_id}) do
    player_locations[map_tile_id]
  end
  def get_player_location(%Instances{player_locations: player_locations} = _state, user_id_hash) do
    player_locations
    |> Map.values
    |> Enum.find(fn location -> location.user_id_hash == user_id_hash end)
  end

  @doc """
  Returns true or false, depending on if the given tile_id responds to the event.
  """
  def responds_to_event?(%Instances{program_registry: program_registry} = _state, %{id: map_tile_id}, event) do
    if program_process = ProgramRegistry.lookup(program_registry, map_tile_id) do
      ProgramProcess.responds_to_event?(program_process, event)
    else
      false
    end
  end

  @doc """
  Send an event to a tile/program.
  Returns the updated state.
  """
  def send_event(%Instances{program_registry: program_registry} = state, %{id: map_tile_id}, event, sender) do
    if program_process = ProgramRegistry.lookup(program_registry, map_tile_id),
      do:   ProgramProcess.send_event(program_process, event, sender),
      else: InstanceProcess.send_standard_behavior(self(), map_tile_id, event, sender)

    state
  end

  @doc """
  Sets the labels for the event sender id. This will be used when a nonstandard message
  is sent in to verify that the event sender may send it.
  """
  def set_message_actions(%Instances{message_actions: message_actions} = state, id, labels) do
    %{ state | message_actions: Map.put(message_actions, id, labels) }
  end

  @doc """
  Removes the labels for the event sender id. This clears the available messages it may send,
  for cases when the sender has chosen an event to send, or for when it is no longer eligible
  to send an event.
  """
  def remove_message_actions(%Instances{message_actions: message_actions} = state, id) do
    %{ state | message_actions: Map.delete(message_actions, id) }
  end

  @doc """
  Returns if the given label is valid for the event sender id. Ie, this player is allowed
  to send that label because the program solicited it via a dialog window, and it is still valid.
  """
  def valid_message_action?(%Instances{message_actions: message_actions} = _state, id, label) do
    case message_actions[id] do
      nil -> false
      labels -> Enum.member?(labels, label)
    end
  end

  @doc """
  Creates the given map tile for the player location in the parent instance state if it does not already exist.
  Returns a tuple containing the created (or already existing) tile, and the updated (or same) state.
  Does not update `dirty_ids` since this tile should already exist in the DB for it to have an id.
  Does touch `rerender_coords` as this may result in something to be rendered.
  """
  def create_player_map_tile(%Instances{player_locations: player_locations} = state, map_tile, location) do
    if state.count_to_idle == 0, do: ProgramRegistry.resume_all_programs(state.program_registry)
    state = if state.count_to_idle < @count_to_idle,
              do: %{ state | count_to_idle: @count_to_idle },
              else: state

    {top, instance_state} = Instances.create_map_tile(state, map_tile)
    {top, %{ instance_state | player_locations: Map.put(player_locations, map_tile.id, location)}}
  end

  @doc """
  Creates the given map tile in the parent instance state if it does not already exist.
  Returns a tuple containing the created (or already existing) tile, and the updated (or same) state.
  Does not update `dirty_ids` since this tile should already exist in the DB for it to have an id.
  Does touch `rerender_coords` as this may result in something to be rendered.
  """
  def create_map_tile(%Instances{new_id_counter: new_id_counter, new_ids: new_ids} = state, %{id: nil} = map_tile) do
    new_id = "new_#{new_id_counter}"
    create_map_tile(%{ state | new_id_counter: new_id_counter + 1, new_ids: Map.put(new_ids, new_id, 0) }, %{ map_tile | id: new_id })
  end

  def create_map_tile(%Instances{} = state, map_tile) do
    map_tile = _with_parsed_state(map_tile)
    {map_tile, state} = _register_map_tile(state, map_tile)
    ProgramRegistry.start_program(state.program_registry, map_tile.id, map_tile.script)
    rerender_coords = Map.put_new(state.rerender_coords, Map.take(map_tile, [:row, :col]), true)
    {map_tile, %{ state | rerender_coords: rerender_coords} }
  end

  defp _with_parsed_state(map_tile) do
    case StateValue.Parser.parse(map_tile.state) do
      {:ok, state} -> Map.put(map_tile, :parsed_state, state)
      _            -> map_tile
    end
  end

  defp _register_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, map_tile) do
     if Map.has_key?(by_id, map_tile.id) do
      # Tile already registered
      {by_id[map_tile.id], state}
    else
      z_index_map = by_coords[{map_tile.row, map_tile.col}] || %{}
      if Map.has_key?(z_index_map, map_tile.z_index) do
        # don't overwrite and add the tile if there's already one registered there
        {by_id[z_index_map[map_tile.z_index]], state}
      else
        by_id = Map.put(by_id, map_tile.id, map_tile)
        by_coords = Map.put(by_coords, {map_tile.row, map_tile.col},
                            Map.put(z_index_map, map_tile.z_index, map_tile.id))
        {map_tile, %Instances{ state | map_by_ids: by_id, map_by_coords: by_coords }}
      end
    end
  end

  @doc """
  Sets a map tile id once it has been persisted to the database. This will update the instance state
  references to the old temporary id to the new id of the map tile record.
  If the map tile's id has already been updated to the id of the database record, then nothing
  will be done and the instance state will be returned unchanged.
  """
  def set_map_tile_id(%Instances{} = state, %{id: new_id} = map_tile, old_temp_id) when is_binary(old_temp_id) and is_integer(new_id) do
    ProgramRegistry.change_program_id(state.program_registry, old_temp_id, new_id)

    by_ids = Map.put(state.map_by_ids, new_id, Map.put(state.map_by_ids[old_temp_id], :id, new_id))
             |> Map.delete(old_temp_id)
    z_indexes = state.map_by_coords[{map_tile.row, map_tile.col}]
                |> Map.put(map_tile.z_index, new_id)
    by_coords = Map.put(state.map_by_coords, {map_tile.row, map_tile.col}, z_indexes)

    %{ state | map_by_ids: by_ids, map_by_coords: by_coords }
  end

  # probably should never hit this, but just in case
  def set_map_tile_id(state, _, _), do: state

  @doc """
  Updates the given map tile's state, returns the updated tile and new instance state.
  `state_attributes` is a map of existing (or new) state values that will replace (or add)
  values already in the state. An existing state attribute (ie, `blocking`) that is not
  included in this map will be unaffected.
  """
  def update_map_tile_state(%Instances{map_by_ids: by_id} = state, %{id: map_tile_id}, state_attributes) do
    map_tile = by_id[map_tile_id]
    state_str = StateValue.Parser.stringify(Map.merge(map_tile.parsed_state, state_attributes))
    update_map_tile(state, map_tile, %{state: state_str})
  end

  @doc """
  Updates the given map tile in the parent instance process, and returns the updated tile and new state.
  If the new attributes include a script, the program will be updated if the script is valid.
  """
  def update_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, %{id: map_tile_id}, new_attributes) do
    new_attributes = Map.delete(new_attributes, :id)
    previous_changeset = state.dirty_ids[map_tile_id] || MapTile.changeset(by_id[map_tile_id], %{})

    if new_attributes[:script] do
      if program_process = ProgramRegistry.lookup(state.program_registry, map_tile_id) do
        ProgramProcess.end_program(program_process)
      end
      if new_attributes[:script] != "" do
        ProgramRegistry.start_program(state.program_registry, map_tile_id, new_attributes[:script])
      end
    end

    updated_tile = by_id[map_tile_id] |> Map.merge(new_attributes)
    updated_tile = _with_parsed_state(updated_tile)

    old_tile_coords = Map.take(by_id[map_tile_id], [:row, :col, :z_index])
    updated_tile_coords = Map.take(updated_tile, [:row, :col, :z_index])

    by_id = Map.put(by_id, map_tile_id, updated_tile)
    dirty_ids = Map.put(state.dirty_ids, map_tile_id, MapTile.changeset(previous_changeset, new_attributes))
    rerender_coords = Map.put_new(state.rerender_coords, Map.take(updated_tile, [:row, :col]), true)
                      |> Map.put_new(Map.take(old_tile_coords, [:row, :col]), true)

    if updated_tile_coords != old_tile_coords do
      z_index_map = by_coords[{updated_tile_coords.row, updated_tile_coords.col}] || %{}

      if Map.has_key?(z_index_map, updated_tile_coords.z_index) do
        # invalid update, just throw it away (or maybe raise an error instead of silently doing nothing)
        {nil, state}
      else
        by_coords = _remove_coord(by_coords, Map.take(old_tile_coords, [:row, :col, :z_index]))
                    |> _put_coord(Map.take(updated_tile_coords, [:row, :col, :z_index]), map_tile_id)
        {updated_tile, %Instances{ state | map_by_ids: by_id, map_by_coords: by_coords, dirty_ids: dirty_ids, rerender_coords: rerender_coords }}
      end
    else
      {updated_tile, %Instances{ state | map_by_ids: by_id, dirty_ids: dirty_ids, rerender_coords: rerender_coords }}
    end
  end

  @doc """
  Deletes the given map tile from the instance state. If there is a player location also associated with that map tile,
  the player location is unregistered.
  Returns a tuple containing the deleted tile (nil if no tile was deleted) and the updated state.
  Passing in false for the third parameter will not mark the map tile for deletion from the database
  during the `write_db` cycle of the instance process. Normally, this parameter can be left out as it defaults to true.
  However, in the case of a player map tile that moves from one instance to another, that map tile will still be persisted
  but will be associated with another instance, so removing it from the instance process is sufficient.
  """
  def delete_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords, player_locations: player_locations, passage_exits: passage_exits} = state, %{id: map_tile_id}, mark_as_dirty \\ true) do
    if program_process = ProgramRegistry.lookup(state.program_registry, map_tile_id) do
      ProgramProcess.end_program(program_process)
    end

    passage_exits = Enum.reject(passage_exits, fn({id, _}) -> id == map_tile_id end)
    dirty_ids = if mark_as_dirty, do: Map.put(state.dirty_ids, map_tile_id, :deleted), else: state.dirty_ids

    map_tile = by_id[map_tile_id]

    if map_tile do
      rerender_coords = Map.put_new(state.rerender_coords, Map.take(map_tile, [:row, :col]), true)
      by_coords = _remove_coord(by_coords, Map.take(map_tile, [:row, :col, :z_index]))
      by_id = Map.delete(by_id, map_tile_id)
      player_locations = Map.delete(player_locations, map_tile_id)
      {map_tile, %Instances{ state |
                             passage_exits: passage_exits,
                             map_by_ids: by_id,
                             map_by_coords: by_coords,
                             dirty_ids: dirty_ids,
                             player_locations: player_locations,
                             rerender_coords: rerender_coords,
                             new_ids: Map.delete(state.new_ids, map_tile_id) }}
    else
      {nil, state}
    end
  end

  @doc """
  Returns the rough direction the given map tile is in, from the given object. Preference will be given to the direction
  which is not immediately blocked. If there are two directions and both are blocked, or both are clear then one will be
  randomly chosen.
  """
  def direction_of_map_tile(state, %MapTile{} = object, %MapTile{} = target_map_tile) do
    case Direction.orthogonal_direction(object, target_map_tile) do
      [direction] ->
        direction

      dirs ->
        non_blocking_dirs = Enum.filter(dirs, fn(dir) -> Move.can_move(Instances.get_map_tile(state, object, dir)) end)
        if length(non_blocking_dirs) == 0, do: Enum.random(dirs), else: Enum.random(non_blocking_dirs)
    end
  end

  defp _remove_coord(by_coords, %{row: row, col: col, z_index: z_index}) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.delete(z_index_map, z_index)
                  _                  -> %{}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end

  defp _put_coord(by_coords, %{row: row, col: col, z_index: z_index}, map_tile_id) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.put(z_index_map, z_index, map_tile_id)
                  _                  -> %{z_index => map_tile_id}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end

  @doc """
  Returns true if the given map_tile_id is a player map tile
  """
  def is_player_tile?(%Instances{player_locations: player_locations}, %{id: map_tile_id}) do
    Map.has_key?(player_locations, map_tile_id)
  end

  @doc """
  Sets a state value for the instance. Returns the updated state
  """
  def set_state_value(%Instances{} = state, key, value) do
    %{ state | state_values: Map.put(state.state_values, key, value) }
  end

  @doc """
  Gets a state value from the instance. Returns the value.
  """
  def get_state_value(%Instances{} = state, key) do
    state.state_values[key]
  end

  @doc """
  Subtracts a amount from the specified state value. Both operands must be numeric.
  Side effects (such as destroying a tile when the health drops to zero, and
  broadcasting the tile changes) will occur for certain scenarios.
  Returns a tuple, including a status atom and the current instance state, which
  may be unchanged if the operation failed.
  For state values other than health, if the amount to subtract is greater than the
  amount available, the state will not be updated and the status atom will be
  `:not_enough`.

  ## Examples

    iex> subtract(state, :cash, 100, 12345)
    {:ok, state}
  """
  def subtract(%Instances{} = state, what, amount, loser_id) do
    loser = Instances.get_map_tile_by_id(state, %{id: loser_id})

    if loser do
      player_location = state.player_locations[loser.id]
      _subtract(state, what, amount, loser, player_location)
    else
      {:no_loser, state}
    end
  end

  def _subtract(%Instances{} = state, :health, amount, loser, nil) do
    current_amount = loser.parsed_state[:health]

    if is_nil(current_amount) && not StateValue.get_bool(loser, :destroyable) do
      {:noop, state}
    else
      new_amount = (current_amount || 0) - amount

      if new_amount <= 0 do
        {_deleted_tile, state} = Instances.delete_map_tile(state, loser)
        loser_coords = Map.take(loser, [:row, :col])

        top_tile = Instances.get_map_tile(state, loser_coords)
        payload = %{tiles: [ Map.put(loser_coords, :rendering, DungeonCrawlWeb.SharedView.tile_and_style(top_tile)) ]}
        DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}", "tile_changes", payload

        {:ok, state}
      else
        {_loser, state} = Instances.update_map_tile_state(state, loser, %{health: new_amount})
        {:ok, state}
      end
    end
  end

  def _subtract(%Instances{} = state, what, amount, loser, nil) do
    new_amount = (loser.parsed_state[what] || 0) - amount

    if new_amount < 0 do
      {:not_enough, state}
    else
      {_loser, state} = Instances.update_map_tile_state(state, loser, %{what => new_amount})
      {:ok, state}
    end
  end

  def _subtract(%Instances{} = state, :health, amount, loser, player_location) do
    new_amount = (loser.parsed_state[:health] || 0) - amount

    cond do
      StateValue.get_bool(loser, :buried) ->
        {:noop, state}

      new_amount <= 0 ->
        {loser, state} = Instances.update_map_tile_state(state, loser, %{health: new_amount})
        {grave, state} = Player.bury(state, loser)
        payload = %{tiles: [
                     Map.put(Map.take(grave, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(grave))
                    ]}
        # TODO: maybe defer broadcasting til in the 50ms instance program cycle, and then consolidate outgoing messages.
        # but this might be ok to do individually, as state updates will happen significantly less often than other
        # tile animations/movements
        DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}", "tile_changes", payload
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: "You died!"}
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(state, loser)}
        {:ok, state}

      true ->
        {loser, state} = Instances.update_map_tile_state(state, loser, %{health: new_amount})
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(state, loser)}
        {:ok, state}
    end
  end

  def _subtract(%Instances{} = state, what, amount, loser, player_location) do
    new_amount = (loser.parsed_state[what] || 0) - amount

    if new_amount < 0 do
      {:not_enough, state}
    else
      {loser, state} = Instances.update_map_tile_state(state, loser, %{what => new_amount})
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(state, loser)}
      {:ok, state}
    end
  end
end

