defmodule DungeonCrawl.DungeonProcesses.Levels do
  @moduledoc """
  The level instances context.
  It wraps the retrival and changes of %Levels{}
  """

  @count_to_idle 5

  defstruct instance_id: nil,
            dungeon_instance_id: nil,
            number: 0,
            player_location_id: nil,
            state_values: %{},
            program_contexts: %{},
            map_by_ids: %{},
            map_by_coords: %{},
            dirty_ids: %{},
            new_ids: %{},
            new_id_counter: 0,
            player_locations: %{},
            dirty_player_tile_stats: [],
            program_messages: [],
            new_pids: [],
            spawn_coordinates: [],
            passage_exits: [],
            message_actions: %{},
            adjacent_level_numbers: %{},
            rerender_coords: %{},
            count_to_idle: @count_to_idle,
            inactive_players: %{},
            players_visible_coords: %{},
            players_los_coords: %{},
            full_rerender: false,
            author: nil,
            light_sources: %{},
            cache: nil,
            sound_effects: [],
            shifted_ids: %{}

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.{Cache, Levels, DungeonRegistry, DungeonProcess, Player}
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scores

  require Logger

  @doc """
  Returns the top tile in the given directon from the provided coordinates.
  """
  def get_tile(state, %{"row" => row, "col" => col} = _tile, direction) do
    get_tile(state, %{row: row, col: col}, direction)
  end
  def get_tile(state, %{row: row, col: col} = _tile, direction) do
    {d_row, d_col} = Direction.delta(direction)
    get_tile(state, %{row: row + d_row, col: col + d_col})
  end
  def get_tile(_,_,_), do: nil

  def get_tile(state, %{"row" => row, "col" => col} = _tile) do
    get_tile(state, %{row: row, col: col})
  end
  def get_tile(%Levels{map_by_ids: by_id, map_by_coords: by_coords} = _state, %{row: row, col: col} = _tile) do
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
  def get_tile(_,_), do: nil

  @doc """
  Returns the tiles in the given directon from the provided coordinates.
  """
  def get_tiles(%Levels{} = state, %{"row" => row, "col" => col} = _tile, direction) do
    get_tiles(state, %{row: row, col: col}, direction)
  end
  def get_tiles(%Levels{} = state, %{row: row, col: col} = _tile, direction) do
    {d_row, d_col} = Direction.delta(direction)
    get_tiles(state, %{row: row + d_row, col: col + d_col})
  end
  def get_tiles(state, %{"row" => row, "col" => col} = _tile) do
    get_tiles(state, %{row: row, col: col})
  end
  def get_tiles(%Levels{map_by_ids: by_id, map_by_coords: by_coords} = _state, %{row: row, col: col} = _tile) do
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
  Gets the tile given by the id.
  """
  def get_tile_by_id(%Levels{map_by_ids: by_id} = _state, %{id: tile_id} = _tile) do
    by_id[tile_id]
  end

  @doc """
  Gets the player location, returns nil if one is not found. Uses a level with an `id` key to lookup based on the tile
  associated with that location. Otherwise lookup is done based on user_id_hash when the parameter is a binary.
  """
  def get_player_location(%Levels{player_locations: player_locations} = _state, %{id: tile_id}) do
    player_locations[tile_id]
  end
  def get_player_location(%Levels{player_locations: player_locations} = _state, user_id_hash) do
    player_locations
    |> Map.values
    |> Enum.find(fn location -> location.user_id_hash == user_id_hash end)
  end

  @doc """
  Returns true or false, depending on if the given tile_id responds to the event.
  """
  def responds_to_event?(%Levels{program_contexts: program_contexts} = _state, %{id: tile_id}, event) do
    with %{^tile_id => %{program: program}} <- program_contexts,
         line_number when not(is_nil(line_number)) <- Program.line_for(program, event) do
      true
    else
      _ ->
        false
    end
  end

  @doc """
  Send an event to a tile/program.
  Returns the updated state.
  """
  def send_event(%Levels{program_contexts: program_contexts} = state, %{id: tile_id}, event, %DungeonCrawl.Player.Location{} = sender, _) do
    case program_contexts do
      %{^tile_id => %{program: program, object_id: object_id}} ->
        sender = Map.drop(sender, [:tile, :inserted_at, :updated_at, :__meta__]) # the struct is still used elsewhere
        %Runner{program: program, state: state} = Scripting.Runner.run(%Runner{program: program,
                                                                               object_id: object_id,
                                                                               state: state,
                                                                               event_sender: sender},
                                                                       event)
                                  |> handle_broadcasting()
        if program.status == :dead do
          %Levels{ state | program_contexts: Map.delete(state.program_contexts, tile_id)}
        else
          updated_program_context = %{program: program, object_id: object_id, event_sender: sender}
          %Levels{ state | program_contexts: Map.put(state.program_contexts, tile_id, updated_program_context)}
        end

      _ ->
        state
    end
  end
  def send_event(%Levels{program_messages: program_messages} = state, tile_id, event, %{} = sender, delay) do
    %{ state | program_messages: [ {tile_id, event, sender, delay} | program_messages] }
  end

  @doc """
  Sets the labels for the event sender id. This will be used when a nonstandard message
  is sent in to verify that the event sender may send it.
  """
  def set_message_actions(%Levels{message_actions: message_actions} = state, id, labels) do
    %{ state | message_actions: Map.put(message_actions, id, labels) }
  end

  @doc """
  Removes the labels for the event sender id. This clears the available messages it may send,
  for cases when the sender has chosen an event to send, or for when it is no longer eligible
  to send an event.
  """
  def remove_message_actions(%Levels{message_actions: message_actions} = state, id) do
    %{ state | message_actions: Map.delete(message_actions, id) }
  end

  @doc """
  Returns if the given label is valid for the event sender id. Ie, this player is allowed
  to send that label because the program solicited it via a dialog window, and it is still valid.
  """
  def valid_message_action?(%Levels{message_actions: message_actions} = _state, id, label) do
    case message_actions[id] do
      nil -> false
      labels -> Enum.member?(labels, label)
    end
  end

  @doc """
  Creates the given tile for the player location in the parent instance state if it does not already exist.
  Returns a tuple containing the created (or already existing) tile, and the updated (or same) state.
  Does not update `dirty_ids` since this tile should already exist in the DB for it to have an id.
  Does touch `rerender_coords` as this may result in something to be rendered.
  """
  def create_player_tile(%Levels{player_locations: player_locations} = state, tile, location) do
    state = if state.count_to_idle < @count_to_idle, do: %{ state | count_to_idle: @count_to_idle }, else: state

    {top, instance_state} = Levels.create_tile(state, tile)
    # put here for now then reconsider when the state string goes away and replaced by "attributes" and "items"
    {top, instance_state} = Levels.update_tile_state(instance_state, top, %{"entry_row" => top.row, "entry_col" => top.col})
    {top, %{ instance_state | player_locations: Map.put(player_locations, tile.id, location)}}
  end

  @doc """
  Creates the given tile in the parent instance state if it does not already exist.
  Returns a tuple containing the created (or already existing) tile, and the updated (or same) state.
  Does not update `dirty_ids` since this tile should already exist in the DB for it to have an id.
  Does touch `rerender_coords` as this may result in something to be rendered.
  """
  def create_tile(state, tile, skip_program \\ false)

  def create_tile(%Levels{new_id_counter: new_id_counter, new_ids: new_ids} = state, %{id: nil} = tile, skip_program) do
    new_id = "new_#{new_id_counter}"
    create_tile(%{ state | new_id_counter: new_id_counter + 1, new_ids: Map.put(new_ids, new_id, 0) }, %{ tile | id: new_id }, skip_program)
  end

  def create_tile(%Levels{} = state, tile, skip_program) do
    {tile, state} = _register_tile(state, tile)
    {_, tile, state} = unless skip_program,
                              do: _parse_and_start_program(state, tile),
                              else: {nil, tile, state}
    rerender_coords = Map.put_new(state.rerender_coords, Map.take(tile, [:row, :col]), true)
    {tile, %{ state | rerender_coords: rerender_coords} }
  end

  defp _register_tile(%Levels{map_by_ids: by_id, map_by_coords: by_coords} = state, tile) do
     if Map.has_key?(by_id, tile.id) do
      # Tile already registered
      {by_id[tile.id], state}
    else
      state = if tile.state["light_source"] == true,
                do: %{ state | light_sources: Map.put(state.light_sources, tile.id, true), players_visible_coords: %{} },
                else: state

      z_index_map = by_coords[{tile.row, tile.col}] || %{}
      if Map.has_key?(z_index_map, tile.z_index) do
        # don't overwrite and add the tile if there's already one registered there
        {by_id[z_index_map[tile.z_index]], state}
      else
        by_id = Map.put(by_id, tile.id, tile)
        by_coords = Map.put(by_coords, {tile.row, tile.col},
                            Map.put(z_index_map, tile.z_index, tile.id))
        {tile, %Levels{ state | map_by_ids: by_id, map_by_coords: by_coords }}
      end
    end
  end

  defp _parse_and_start_program(state, tile) do
    case Scripting.Parser.parse(tile.script) do
     {:ok, program} ->
       unless program.status == :dead do
         {:ok, tile, _start_program(state, tile.id, %{program: program, object_id: tile.id, event_sender: nil})}
       else
         {:none, tile, state}
       end
     other ->
       Logger.warning """
                      Possible corrupt script for tile instance: #{inspect tile}
                      Not :ok response: #{inspect other}
                      """
       {:none, tile, state}
    end
  end

  defp _start_program(%Levels{program_contexts: program_contexts, new_pids: new_pids} = state, tile_id, program_context) do
    if Map.has_key?(program_contexts, tile_id) do
      # already a running program for that tile id, or there is no tile for that id
      state
    else
      %Levels{ state | program_contexts: Map.put(program_contexts, tile_id, program_context),
                          new_pids: [tile_id | new_pids]}
    end
  end

  @doc """
  Sets a tile id once it has been persisted to the database. This will update the instance state
  references to the old temporary id to the new id of the tile record.
  If the tile's id has already been updated to the id of the database record, then nothing
  will be done and the instance state will be returned unchanged.
  """
  def set_tile_id(%Levels{} = state, %{id: new_id} = tile, old_temp_id) when is_binary(old_temp_id) and is_integer(new_id) do
    by_ids = Map.put(state.map_by_ids, new_id, Map.put(state.map_by_ids[old_temp_id], :id, new_id))
             |> Map.delete(old_temp_id)
    z_indexes = state.map_by_coords[{tile.row, tile.col}]
                |> Map.put(tile.z_index, new_id)
    by_coords = Map.put(state.map_by_coords, {tile.row, tile.col}, z_indexes)
    program_contexts = if state.program_contexts[old_temp_id] do
                         Map.put(state.program_contexts, new_id, %{ state.program_contexts[old_temp_id] | object_id: new_id} )
                         |> Map.delete(old_temp_id)
                       else
                         state.program_contexts
                       end
    program_contexts = program_contexts
                       |> Map.to_list
                       |> Enum.map(fn({pid, %{event_sender: event_sender, program: program} = program_context}) ->
                            event_sender = if event_sender && Map.get(event_sender, :tile_id) == old_temp_id do
                                             %{ event_sender | tile_id: new_id}
                                           else
                                             event_sender
                                           end
                            messages = program.messages
                                       |> Enum.map(fn({label, sender} = message) ->
                                            case sender do
                                              %{tile_id: tile_id} when tile_id == old_temp_id ->
                                                {label, %{sender | tile_id: new_id}}
                                              _ ->
                                                message
                                            end
                                          end)
                            {pid, %{program_context | event_sender: event_sender, program: %{ program | messages: messages}}}
                          end)
                       |> Enum.into(%{})

    %{ state | map_by_ids: by_ids, map_by_coords: by_coords, program_contexts: program_contexts }
  end

  # probably should never hit this, but just in case
  def set_tile_id(state, _, _), do: state

  @doc """
  Updates the given tile's state, returns the updated tile and new instance state.
  `state_attributes` is a map of existing (or new) state values that will replace (or add)
  values already in the state. An existing state attribute (ie, `blocking`) that is not
  included in this map will be unaffected.
  """
  @ignorable_state_attrs ["entry_row", "entry_col", "steps", "already_touched"]
  def update_tile_state(%Levels{map_by_ids: by_id} = state, %{id: tile_id}, state_attributes) do
    tile = by_id[tile_id]
    tile_state = Map.merge(tile.state || %{}, state_attributes)

    # handle change to light sources
    state = cond do
              state_attributes["light_source"] == true ->
                %{state | light_sources: Map.put_new(state.light_sources, tile_id, true), players_los_coords: %{}}
              Map.has_key?(state_attributes, "light_source") ->
                %{state | light_sources: Map.delete(state.light_sources, tile_id), players_los_coords: %{}}
              Map.has_key?(state_attributes, "light_range") ->
                %{state | players_los_coords: %{}}
              true ->
                state
            end

    if state.player_locations[tile_id] &&
       not Enum.any?(Map.keys(state_attributes), fn key -> Enum.member?(@ignorable_state_attrs, key) end) do
      dirty_stats = [ tile_id | state.dirty_player_tile_stats ]
      update_tile(%{ state | dirty_player_tile_stats: dirty_stats }, tile, %{state: tile_state})
    else
      update_tile(state, tile, %{state: tile_state})
    end
  end

  @doc """
  Updates the given tile in the parent instance process, and returns the updated tile and new state.
  If the new attributes include a script, the program will be updated if the script is valid.
  `update_tile_state` should be used instead when there are state updates to be merged in with
  the tiles current state.
  """
  def update_tile(%Levels{map_by_ids: by_id, map_by_coords: by_coords} = state, %{id: tile_id}, new_attributes) do
    new_attributes = Map.delete(new_attributes, "id")
    previous_changeset = state.dirty_ids[tile_id] || Tile.changeset(by_id[tile_id], %{})
    new_changeset = Tile.changeset(previous_changeset, new_attributes)

    script_changed = !!new_attributes["script"]

    old_tile = by_id[tile_id]
    updated_tile = old_tile
                   |> Map.merge(new_changeset.changes)

    by_id = Map.put(by_id, tile_id, updated_tile)
    dirty_ids = Map.put(state.dirty_ids, tile_id, new_changeset)

    rerender_coords = if _rerender_needed(updated_tile, old_tile),
                         do: Map.put_new(state.rerender_coords, Map.take(updated_tile, [:row, :col]), true)
                             |> Map.put_new(Map.take(old_tile, [:row, :col]), true),
                         else: state.rerender_coords

    if _coords_changed(updated_tile, old_tile) do
      z_index_map = by_coords[{updated_tile.row, updated_tile.col}] || %{}

      if Map.has_key?(z_index_map, updated_tile.z_index) do
        # invalid update, just throw it away (or maybe raise an error instead of silently doing nothing)
        {nil, state}
      else
        players_los_coords = if Map.has_key?(updated_tile.state, "light_source"),
                               do: %{},
                               else: state.players_los_coords

        by_coords = _remove_coord(by_coords, Map.take(old_tile, [:row, :col, :z_index]))
                    |> _put_coord(Map.take(updated_tile, [:row, :col, :z_index]), tile_id)
        {updated_tile, %Levels{ state | map_by_ids: by_id,
                                        map_by_coords: by_coords,
                                        dirty_ids: dirty_ids,
                                        rerender_coords: rerender_coords,
                                        players_los_coords: players_los_coords}}
        |> _update_program(script_changed)
      end
    else
      {updated_tile, %Levels{ state | map_by_ids: by_id, dirty_ids: dirty_ids, rerender_coords: rerender_coords }}
      |> _update_program(script_changed)
    end
  end

  @rerenderables [
    :row,
    :col,
    :z_index,
    :character,
    :color,
    :background_color,
    :animate_random,
    :animate_colors,
    :animate_background_colors,
    :animate_characters,
    :animate_period
  ]

  defp _coords_changed(updated_tile, old_tile) do
    Map.take(updated_tile, [:row, :col, :z_index]) !=
      Map.take(old_tile, [:row, :col, :z_index])
  end

  defp _rerender_needed(updated_tile, old_tile) do
    _coords_changed(updated_tile, old_tile) ||
    Map.take(updated_tile, @rerenderables) !=
      Map.take(old_tile, @rerenderables)
  end

  defp _update_program({tile, %Levels{} = state}, false), do: {tile, state}
  defp _update_program({tile, %Levels{} = state}, true) do
    {previous_program, program_contexts} = Map.pop(state.program_contexts, tile.id)
    _update_program(previous_program || %{},
                    _parse_and_start_program(%Levels{state | program_contexts: program_contexts}, tile))
  end
  defp _update_program(_previous_program, {:none, tile, state}) do
    {tile, state}
  end
  defp _update_program(previous_program, {:ok, tile, state}) do
    new_program = state.program_contexts[tile.id].program
                  |> Map.merge(Map.take(previous_program, [:broadcasts, :responses]))
                  |> Map.put(:status, :wait)

    updated_context = %{ state.program_contexts[tile.id] | program: new_program }

    {tile, %Levels{ state | program_contexts: Map.put(state.program_contexts, tile.id, updated_context) }}
  end

  @doc """
  Deletes the given tile from the instance state. If there is a player location also associated with that tile,
  the player location is unregistered.
  Returns a tuple containing the deleted tile (nil if no tile was deleted) and the updated state.
  Passing in false for the third parameter will not mark the tile for deletion from the database
  during the `write_db` cycle of the instance process. Normally, this parameter can be left out as it defaults to true.
  However, in the case of a player tile that moves from one instance to another, that tile will still be persisted
  but will be associated with another instance, so removing it from the instance process is sufficient.
  """
  def delete_tile(%Levels{program_contexts: program_contexts,
                          map_by_ids: by_id,
                          map_by_coords: by_coords,
                          player_locations: player_locations,
                          players_visible_coords: players_visible_coords,
                          players_los_coords: players_los_coords,
                          passage_exits: passage_exits} = state,
                      %{id: tile_id},
                      mark_as_dirty \\ true) do
    program_contexts = Map.delete(program_contexts, tile_id)
    passage_exits = Enum.reject(passage_exits, fn({id, _}) -> id == tile_id end)
    dirty_ids = if mark_as_dirty, do: Map.put(state.dirty_ids, tile_id, :deleted), else: state.dirty_ids
    dirty_ids = if is_integer(tile_id), do: dirty_ids, else: Map.delete(dirty_ids, tile_id)

    tile = by_id[tile_id]

    if tile do
      rerender_coords = Map.put_new(state.rerender_coords, Map.take(tile, [:row, :col]), true)
      by_coords = _remove_coord(by_coords, Map.take(tile, [:row, :col, :z_index]))
      by_id = Map.delete(by_id, tile_id)
      player_locations = Map.delete(player_locations, tile_id)
      players_visible_coords = Map.delete(players_visible_coords, tile_id)
      players_los_coords = if tile.state["light_source"] == true,
                             do: %{},
                             else: Map.delete(players_los_coords, tile_id)

      {tile, %Levels{ state |
                      program_contexts: program_contexts,
                      passage_exits: passage_exits,
                      map_by_ids: by_id,
                      map_by_coords: by_coords,
                      dirty_ids: dirty_ids,
                      player_locations: player_locations,
                      players_visible_coords: players_visible_coords,
                      players_los_coords: players_los_coords,
                      rerender_coords: rerender_coords,
                      new_ids: Map.delete(state.new_ids, tile_id),
                      inactive_players: Map.delete(state.inactive_players, tile_id),
                      light_sources: Map.delete(state.light_sources, tile_id)}}
    else
      {nil, state}
    end
  end

  @doc """
  Returns the rough direction the given tile is in, from the given object. Preference will be given to the direction
  which is not immediately blocked. If there are two directions and both are blocked, or both are clear then one will be
  randomly chosen.
  """
  def direction_of_tile(state, %Tile{} = object, %Tile{} = target_tile) do
    case Direction.orthogonal_direction(object, target_tile) do
      [direction] ->
        direction

      dirs ->
        non_blocking_dirs = Enum.filter(dirs, fn(dir) -> Move.can_move(Levels.get_tile(state, object, dir)) end)
        if length(non_blocking_dirs) == 0, do: Enum.random(dirs), else: Enum.random(non_blocking_dirs)
    end
  end

  @doc """
  Takes a program context, and sends all queued up broadcasts. Returns the context with broadcast queues emtpied.
  """
  def handle_broadcasting(%{state: state} = runner_context) do
    _handle_broadcasts(Enum.reverse(runner_context.program.broadcasts), "level:#{state.dungeon_instance_id}:#{state.number}:#{state.player_location_id}")
    _handle_broadcasts(Enum.reverse(runner_context.program.responses), runner_context.event_sender)
    %{ runner_context | program: %{ runner_context.program | responses: [], broadcasts: [] } }
  end

  defp _handle_broadcasts([ [event, payload] | messages], socket) when is_binary(socket) do
    DungeonCrawlWeb.Endpoint.broadcast socket, event, payload
    _handle_broadcasts(messages, socket)
  end
  defp _handle_broadcasts([{type, payload} | messages], player_location = %DungeonCrawl.Player.Location{}) do
    DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", type, payload
    _handle_broadcasts(messages, player_location)
  end
  # If this should be implemented, this is what broadcasting to a "program" method would look like.
  # Could also just use an id that is assumed to be the linked tile for the program. Since this
  # is used to figure out what channel to send text, programs wouldnt really do anythign with it.
#  defp _handle_broadcasts([message | messages], player_location = %DungeonCrawl.DungeonInstances.Tile{}), do: 'implement'
  defp _handle_broadcasts(_, _), do: nil

  defp _remove_coord(by_coords, %{row: row, col: col, z_index: z_index}) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.delete(z_index_map, z_index)
                  _                  -> %{}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end

  defp _put_coord(by_coords, %{row: row, col: col, z_index: z_index}, tile_id) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.put(z_index_map, z_index, tile_id)
                  _                  -> %{z_index => tile_id}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end

  @doc """
  Returns true if the given tile_id is a player tile
  """
  def is_player_tile?(%Levels{player_locations: player_locations}, %{id: tile_id}) do
    Map.has_key?(player_locations, tile_id)
  end

  @doc """
  Sets a state value for the instance. Returns the updated state
  """
  def set_state_value(%Levels{} = state, key, value) do
    %{ state | state_values: Map.put(state.state_values, key, value) }
  end

  @doc """
  Gets a state value from the instance. Returns the value.
  """
  def get_state_value(%Levels{} = state, key) do
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

    iex> subtract(state, "cash", 100, 12345)
    {:ok, state}
  """
  def subtract(%Levels{} = state, what, amount, loser_id) when is_binary(what) do
    loser = Levels.get_tile_by_id(state, %{id: loser_id})

    if loser do
      player_location = state.player_locations[loser.id]
      _subtract(state, what, amount, loser, player_location)
    else
      {:no_loser, state}
    end
  end

  def _subtract(%Levels{} = state, "health", amount, loser, nil) do
    current_amount = loser.state["health"]

    if is_nil(current_amount) && not StateValue.get_bool(loser, "destroyable") do
      {:noop, state}
    else
      new_amount = (current_amount || 0) - amount

      if new_amount <= 0 do
        {_deleted_tile, state} = Levels.delete_tile(state, loser)
        {:died, state}
      else
        {_loser, state} = Levels.update_tile_state(state, loser, %{"health" => new_amount})
        {:ok, state}
      end
    end
  end

  def _subtract(%Levels{} = state, what, amount, loser, nil) do
    new_amount = (loser.state[what] || 0) - amount

    if new_amount < 0 do
      {:not_enough, state}
    else
      {_loser, state} = Levels.update_tile_state(state, loser, %{what => new_amount})
      {:ok, state}
    end
  end

  def _subtract(%Levels{} = state, "health", amount, loser, player_location) do
    new_amount = (loser.state["health"] || 0) - amount

    cond do
      StateValue.get_bool(loser, "buried") || StateValue.get_bool(loser, "gameover") ->
        {:noop, state}

      new_amount <= 0 ->
        lives = if loser.state["lives"] > 0, do: loser.state["lives"] - 1, else: -1
        {loser, state} = Levels.update_tile_state(state, loser, %{"health" => new_amount, "lives" => lives})
        {_grave, state} = Player.bury(state, loser)

        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: "You died!"}
        state = _add_sound_effect(state, loser, "harp_down")

        if lives == 0 do
          {:ok, gameover(state, loser.id, false, "Dead")}
        else
          {:ok, state}
        end

      state.state_values["reset_player_when_damaged"] ->
        state = _add_sound_effect(state, loser, "ouch")

        {loser, state} = Levels.update_tile_state(state, loser, %{"health" => new_amount})
        {_loser, state} = Player.reset(state, loser)
        {:ok, state}

      true ->
        state = _add_sound_effect(state, loser, "ouch")

        {_loser, state} = Levels.update_tile_state(state, loser, %{"health" => new_amount})
        {:ok, state}
    end
  end

  def _subtract(%Levels{} = state, what, amount, loser, _player_location) do
    new_amount = (loser.state[what] || 0) - amount

    if new_amount < 0 do
      {:not_enough, state}
    else
      {_loser, state} = Levels.update_tile_state(state, loser, %{what => new_amount})

      {:ok, state}
    end
  end

  def _add_sound_effect(state, player_tile, slug) do
    {effect, state, _} = get_sound_effect(slug, state)

    if effect do
      effect_info = %{row: player_tile.row,
                      col: player_tile.col,
                      target: state.player_locations[player_tile.id],
                      zzfx_params: effect.zzfx_params}
      %{ state | sound_effects: [ effect_info | state.sound_effects]}
    else
      state
    end
  end

  @doc """
  Looks up a tile template from the cache, falling back to getting it from the database and saving for later.
  Returns a three part tuple, the first being the tile template if found, the state, and an atom indicating if it
  exists in cache, was created in the cache, or not_found.
  """
  def get_tile_template(slug, %Levels{cache: cache, author: author} = state) do
    {tile_template, result} = Cache.get_tile_template(cache, slug, author)
    {tile_template, state, result}
  end

  @doc """
  Looks up an item from the cache, falling back to getting it from the database and saving for later.
  Returns a three part tuple, the first being the item if found, the instance state, and an atom indicating if it
  exists in cache, was created in the cache, or not_found.
  """
  def get_item(slug, %Levels{cache: cache, author: author} = state) do
    {item, result} = Cache.get_item(cache, slug, author)
    {item, state, result}
  end

  @doc """
  Looks up a sound effect from the cache, falling back to getting it from the database and saving for later.
  Returns a three part tuple, the first being the effect if found, the instance state, and an atom indicating if it
  exists in cache, was created in the cache, or not_found.
  """
  def get_sound_effect(slug, %Levels{cache: cache, author: author} = state) do
    {sound_effect, result} = Cache.get_sound_effect(cache, slug, author)
    {sound_effect, state, result}
  end

  @doc """
  Update the given player tile to gameover. Broadcasts the gameover message to the appropriate channel.
  Creates a score record if applicable.
  """
  def gameover(%Levels{} = state, victory, result) do
    state.player_locations
    |> Map.keys()
    |> Enum.reduce(state, fn(player_tile_id, state) ->
                            gameover(state, player_tile_id, victory, result)
                          end)
  end

  def gameover(%Levels{} = state, player_tile_id, victory, result) do
    with tile when not is_nil(tile) <- Levels.get_tile_by_id(state, %{id: player_tile_id}),
         #%{^player_tile_id => player_location} <- state.player_locations,
         player_location when not is_nil(player_location) <- state.player_locations[player_tile_id],
         {:ok, dungeon_process} <- DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id),
         dungeon when not is_nil(dungeon) <- DungeonProcess.get_dungeon(dungeon_process),
         scorable = DungeonProcess.scorable?(dungeon_process),
         autogenerated = DungeonProcess.get_dungeon(dungeon_process).autogenerated do

      # TODO: update scoers to allow nil dungeon_id, which indicates it was an autogenerated solo dungeon score
      cond do
        not scorable ->
          {_player_tile, state} = Levels.update_tile_state(state, tile, %{"gameover" => true})
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "gameover",
                                             %{}
          state

        tile.state["gameover"] ->
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "gameover",
                                             %{score_id: tile.state["score_id"], dungeon_id: tile.state["dungeon_id"]}
          state

        !autogenerated && Enum.member?(["Idled Out", "Gave Up"], result) ->
          state

        true ->
          seconds = NaiveDateTime.diff(NaiveDateTime.utc_now, player_location.inserted_at) +
            (tile.state["duration"] || 0)

          {result, dungeon_id} = if autogenerated, do: {"#{result}, Level: #{state.number}", nil}, else: {result, dungeon.id}

          attrs = %{"duration" => seconds,
                    "result" => result,
                    "score" => tile.state["score"],
                    "steps" => tile.state["steps"],
                    "deaths" => tile.state["deaths"] || 0,
                    "victory" => victory,
                    "user_id_hash" => player_location.user_id_hash,
                    "dungeon_id" => dungeon_id}

          {:ok, score} = Scores.create_score(attrs)
          {_player_tile, state} = Levels.update_tile_state(state, tile, %{"gameover" => true,
                                                                          "score_id" => score.id,
                                                                          "dungeon_id" => score.dungeon_id})
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "gameover",
                                             %{dungeon_id: score.dungeon_id, score_id: score.id}
          state
      end
    else
      _ ->
        state
    end
  end
end

