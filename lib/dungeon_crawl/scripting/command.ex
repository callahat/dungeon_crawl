defmodule DungeonCrawl.Scripting.Command do
  @moduledoc """
  The various scripting commands available to a program.
  """

  alias DungeonCrawl.Action.{Move, Shoot}
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.Maths
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.TileTemplates

  @doc """
  Returns the script command for given name. If the name has no corresponding command, then nil is returned.
  This can be useful for validating if a command exists or not.

  ## Examples

    iex> Command.get_command("noop")
    :noop
    iex> Command.get_command("end")
    :halt
    iex> Command.get_command("not_real")
    nil
  """
  def get_command(name) when is_binary(name), do: get_command(String.downcase(name) |> String.trim() |> String.to_atom())
  def get_command(name) do
    case name do
      :become       -> :become
      :change_state -> :change_state
      :change_instance_state -> :change_instance_state
      :cycle        -> :cycle
      :die          -> :die
      :end          -> :halt
      :facing       -> :facing
      :give         -> :give
      :go           -> :go
      :if           -> :jump_if
      :lock         -> :lock
      :move         -> :move
      :noop         -> :noop
      :restore      -> :restore
      :send         -> :send_message
      :shoot        -> :shoot
      :terminate    -> :terminate
      :take         -> :take
      :text         -> :text
      :try          -> :try
      :unlock       -> :unlock
      :walk         -> :walk
      :zap          -> :zap

      _ -> nil
    end
  end

  @doc """
  Transforms the object refernced by the id in some way. Changes can include character, color, background color, state, script
  and tile_template_id. Just changing the tile_template_id does not copy all other attributes of that tile template
  to the object.

  Changes will be persisted to the database, and a message added to the broadcasts list for the tile_changes that
  occurred.

  ## Examples

    iex> Command.become(%Runner{}, [%{character: $}])
    %Runner{program: %{program | broadcasts: [ ["tile_changes", %{tiles: [%{row: 1, col: 1, rendering: "<div>$</div>"}]}] ]},
            object_id: object_id,
            state: updated_state }
  """
  def become(%Runner{} = runner_state, [{:ttid, ttid}]) do
    new_attrs = Map.take(TileTemplates.get_tile_template!(ttid), [:character, :color, :background_color, :state, :script])
    _become(runner_state, Map.put(new_attrs, :tile_template_id, ttid))
  end
  def become(%Runner{} = runner_state, [params]) do
    new_attrs = Map.take(params, [:character, :color, :background_color, :state, :script, :tile_template_id])
    _become(runner_state, new_attrs)
  end
  def _become(%Runner{program: program, object_id: object_id, state: state} = runner_state, new_attrs) do
    {object, state} = Instances.update_map_tile(
                      state,
                      %{id: object_id},
                      new_attrs)

    message = ["tile_changes",
               %{tiles: [
                   Map.put(Map.take(object, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(object))
               ]}]

    current_program = cond do
                        is_nil(Map.get(state.program_contexts, object.id)) ->
                          %{ program | status: :dead }
                        Map.has_key?(new_attrs, :script) ->
                          # A changed script will update the program, so get the current
                          Map.get(state.program_contexts, object.id).program
                        true ->
                          program
                      end
    %{ runner_state |
         program: %{current_program | broadcasts: [message | program.broadcasts] },
         object_id: object_id,
         state: state }
  end

  @doc """
  Changes the object's state element given in params. The params also specify what operation is being used,
  and the value to use in conjunction with the value from the state. When there is no state value;
  0 is used as default. The params list is ordered:

  [<name of the state value>, <operator>, <right side value>]

  See the Maths module calc function definitions for valid operators.

  When it is a binary operator (ie, "=", "+=" etc) the right side value is used to change the object's
  state value by adding it, subtracting it, setting it, etc with the right side value.

  Change is persisted to the DB for the object (map_tile instance)

  Case sensitive

  ## Examples

    iex> Command.change_state(%Runner{program: program,
                                      object_id: 1,
                                      state: %Instances{map_by_ids: %{1 => %{state: "counter: 1"},...}, ...}},
                              [:counter, "+=", 3])
    %Runner{program: program,
            state: %Instances{map_by_ids: %{1 => %{state: "counter: 4"},...}, ...} }
  """
  def change_state(%Runner{object_id: object_id, state: state} = runner_state, params) do
    [var, op, value] = params

    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object_state = Map.put(object.parsed_state, var, Maths.calc(object.parsed_state[var] || 0, op, value))
    object_state_str = StateValue.Parser.stringify(object_state)
    {_updated_object, updated_state} = Instances.update_map_tile(state, object, %{state: object_state_str, parsed_state: object_state})

    %Runner{ runner_state | state: updated_state }
  end

  @doc """
  Changes the instance state_values element given in params. (Similar to change_state)

  ## Examples

    iex> Command.change_instance_state(%Runner{program: program,
                                               state: %Instances{state_values: %{}}},
                                       [:counter, "+=", 3])
    %Runner{program: program,
            state: %Instances{map_by_ids: %{1 => %{state: "counter: 4"},...}, ...} }
  """
  def change_instance_state(%Runner{state: state} = runner_state, params) do
    [var, op, value] = params

    state_values = Map.put(state.state_values, var, Maths.calc(state.state_values[var] || 0, op, value))

    %Runner{ runner_state | state: %{ state | state_values: state_values } }
  end

  @doc """
  Similar to MOVE. This method is not directly accessable in the script as a normal command.
  Rather, a line of short hand movement commands will be parsed and run via `compound_move`.
  A short hand movement is two characters. A backslash or a question mark followed by a
  direction character (n, s, e, w, or i, case insensitive).

  A forward slash will retry that movement until successful (unless the program also responds to
  THUD). A question mark will attempt the movement once and then move on with the next instruction.
  If the movement is invalid, the `pc` will be set to the location of the `THUD` label if an active one exists.

  Valid directions:
  n - up
  s - down
  e - right
  w - left
  i - no movement
  c - continue

  Shorthand examples:

  /n/n/n - move north three times
  /e?n?n - move east once, then try to move north twice

  For purposes of keeping track of which of the shorthand movements the command is on, the `lc` - line counter
  element on the program is used.

  The parameters expected are an enumerable containing tuples of 2. The first element of the tuple, and the second
  is if the movement should retry until successful. The behavior is similar to the regular move command.

  ## Examples

    iex> Command.compound_move(%Runner{program: %Program{},
                                       object_id: object_id,
                                       state: state},
                               [{"north", true}, {"east", false}])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Instances{map_by_ids: %{object_id => %{object | row: object.row - 1}}}}
  """
  def compound_move(%Runner{program: program} = runner_state, movement_chain) do
    case Enum.at(movement_chain, program.lc) do
      nil ->
        %{ runner_state | program: %{ program | lc: 0 } }

      {direction, retry_until_successful} ->
        next_actions = %{pc: program.pc - 1, lc: program.lc + 1, invalid_move_handler: &_invalid_compound_command/2}
        _move(runner_state, direction, retry_until_successful, next_actions)
    end
  end

  @doc """
  Sets the cycle speed of the object. The cycle speed is how quickly the object moves.
  It defaults to 5 (about one move every 5 ticks, where a tick is ~100ms currently).
  The lower the number the faster. Lowest it can be set is 1.
  The underlying state value `wait_cycles` can also be directly set via the state
  shorthand `@`. Extra care will be needed to make sure the parameter and changes
  are valid.

  ## Examples

    iex> Command.cycle(%Runner{}, [1])
    %Runner{program: program,
            state: %Instances{ map_by_ids: %{object_id => %{ object | state: "cycle: 1" } } } }
  """
  def cycle(runner_state, [wait_cycles]) do
    if wait_cycles < 1 do
      runner_state
    else
      change_state(runner_state, [:wait_cycles, "=", wait_cycles])
    end
  end

  @doc """
  Kills the script for the object. Returns a dead program, and deletes the object from the instance state

  ## Examples

    iex> Command.die(%Runner{program: program,
                             object_id: object_id,
                             state: %Instances{ map_by_ids: %{object_id => %{ script: ... } } }}
    %Runner{program: %{program | pc: -1, status: :dead},
            object_id: object_id,
            state: %Instances{ map_by_ids: %{ ... } } }
  """
  def die(%Runner{program: program, object_id: object_id, state: state} = runner_state, _ignored \\ nil) do
    {deleted_object, updated_state} = Instances.delete_map_tile(state, %{id: object_id})
    top_tile = Instances.get_map_tile(updated_state, deleted_object)

    message = ["tile_changes",
               %{tiles: [
                   Map.put(Map.take(deleted_object, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(top_tile))
               ]}]

    %Runner{runner_state |
            program: %{program | status: :dead, pc: -1, broadcasts: [message | program.broadcasts]},
            state: updated_state}
  end

  @doc """
  Give a tile an amount of something. This modifies the state of that tile by adding the amount to
  whatever is at that key is at (creating it if not already present). First parameter is `what` (the
  state field, ie `ammo`), second the quantity (must be a positive number). Quantity may reference a state
  value for the giving tile. Third is the receiving tile of it. Fourth and fifth parameters are max amount
  the recieving tile may have (the command will give up to this amount if present). If receiving tile is already
  at max, then the fifth parameter is the label where the script will continue running from. Forth and fifth are
  optional, but the fifth parameter will require a valid fourth parameter.

  Valid tiles can be a direction - ie, north, south east, west; additionally
  the specail varialble `?sender` can be used to give to the program/player
  that sent the last event. For example, if a player touches a certain object,
  that object could give them gems.

  ## Examples

    iex> Command.give(%Runner{}, [:cash, :420, [:event_sender]])
    %Runner{}
    iex> Command.give(%Runner{}, [:ammo, {:state_variable, :rounds}, "north"])
    %Runner{}
    iex> Command.give(%Runner{}, [:health, 100, "north", 100, "HEALEDUP"])
    %Runner{}
  """
  def give(%Runner{} = runner_state, [what, amount, to_whom]) do
    _give(runner_state, [what, amount, to_whom, nil, nil])
  end

  def give(%Runner{} = runner_state, [what, amount, to_whom, max]) do
    _give(runner_state, [what, amount, to_whom, max, nil])
  end

  def give(%Runner{} = runner_state, [what, amount, to_whom, max, label]) do
    _give(runner_state, [what, amount, to_whom, max, label])
  end

  defp _give(%Runner{event_sender: event_sender} = runner_state, [what, amount, [:event_sender], max, label]) do
    case event_sender do
      %{map_tile_id: id} -> _give(runner_state, [what, amount, [id], max, label])

      %Location{map_tile_instance_id: id} -> _give(runner_state, [what, amount, [id], max, label])

      nil              -> runner_state
    end
  end

  defp _give(%Runner{} = runner_state, [what, amount, [id], max, label]) do
    _give_via_id(runner_state, [what, amount, [id], max, label])
  end

  defp _give(%Runner{object_id: object_id, state: state} = runner_state, [what, amount, direction, max, label]) do
    if direction in ["north", "up", "south", "down", "east", "right", "west", "left"] do
      object = Instances.get_map_tile_by_id(state, %{id: object_id})
      map_tile = Instances.get_map_tile(state, object, direction)

      if map_tile do
        _give(runner_state, [what, amount, [map_tile.id], max, label])
      else
        runner_state
      end
    else
      runner_state
    end
  end

  defp _give_via_id(%Runner{state: state, object_id: object_id, event_sender: sender} = runner_state, [what, amount, [id], max, label]) do
    amount = _resolve_variable(runner_state, amount)
    what = _resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      max = _resolve_variable(runner_state, max)
      receiver = Instances.get_map_tile_by_id(state, %{id: id})
      what = String.to_atom(what)
      current_value = receiver.parsed_state[what] || 0
      adjusted_amount = _adjust_amount_to_give(amount, max, current_value)
      new_value = current_value + adjusted_amount

      cond do
        adjusted_amount > 0 ->
          {_receiver, state} = Instances.update_map_tile_state(state, receiver, %{what => new_value})

          if state.player_locations[id] do
            payload = %{stats: PlayerInstance.current_stats(state, %DungeonCrawl.DungeonInstances.MapTile{id: id})}
            %{ runner_state | program: %{runner_state.program | responses: [ {"stat_update", payload} | runner_state.program.responses] }, state: state }
          else
            %{ runner_state | state: state }
          end

        is_number(max) && label ->
          state = %{ state | program_messages: [ {object_id, label, sender} | state.program_messages] }
          %{ runner_state | state: state, program: state.program_contexts[object_id].program }

        true ->
          runner_state
      end
    else
      runner_state
    end
  end

  defp _adjust_amount_to_give(amount, max, current_amount) do
    if is_number(max) and current_amount + amount >= max do
      max - current_amount
    else
      amount
    end
  end

  @doc """
  Move in the given direction, and keep retrying until successful.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.go(%Runner{program: %Program{},
                                       object_id: object_id,
                                       state: state},
                    ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Instances{map_by_ids: %{object_id => %{object | row: object.row - 1}}}}
  """
  def go(runner_state, [direction]) do
    move(runner_state, [direction, true])
  end

  @doc """
  Changes the program state to idle and sets the pc to -1. This indicates that the program is still alive,
  but awaiting a message to respond to (ie, a TOUCH event)
  END is what would be put in the script.

  ## Examples

    iex> Command.halt(%Runner{program: program, state: state})
    %Runner{program: %{program | pc: -1, status: :idle},
            state: state }
  """
  def halt(%Runner{program: program} = runner_state, _ignored \\ nil) do
    %{ runner_state | program: %{program | status: :idle, pc: -1} }
  end

  @doc """
  Changes the direction the object is facing. Nothing done if the object has no facing if
  reverse, clockwise, or counterclockwise is specified.

  north, up
  south, down
  east, right
  west, left
  reverse - reverses the current facing direction (ie, north becomes south)
  clockwise - turns the current facing clockwise (ie, north becomes west)
  counterclockwise - turns the current facing counter clockwise (ie, north becomes east)
  """
  def facing(%Runner{} = runner_state, ["player"]) do
    {new_runner_state, player_direction} = _direction_of_player(runner_state)
    _facing(new_runner_state, player_direction)
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, ["clockwise"]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = case object.parsed_state[:facing] do
                  "left"  -> "north"
                  "west"  -> "north"
                  "up"    -> "east"
                  "north" -> "east"
                  "right" -> "south"
                  "east"  -> "south"
                  "down"  -> "west"
                  "south" -> "west"
                  _       -> "idle"
                end
    _facing(runner_state, direction)
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, ["counterclockwise"]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = case object.parsed_state[:facing] do
                  "left"  -> "south"
                  "west"  -> "south"
                  "up"    -> "west"
                  "north" -> "west"
                  "right" -> "north"
                  "east"  -> "north"
                  "down"  -> "east"
                  "south" -> "east"
                  _       -> "idle"
                end
    _facing(runner_state, direction)
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, ["reverse"]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = case object.parsed_state[:facing] do
                  "left"  -> "east"
                  "west"  -> "east"
                  "up"    -> "south"
                  "north" -> "south"
                  "right" -> "west"
                  "east"  -> "west"
                  "down"  -> "north"
                  "south" -> "north"
                  _       -> "idle"
                end
    _facing(runner_state, direction)
  end
  def facing(runner_state, [direction]) do
    _facing(runner_state, direction)
  end
  def _facing(runner_state, direction) do
    runner_state = change_state(runner_state, [:facing, "=", direction])
    %{ runner_state | program: %{runner_state.program | status: :wait, wait_cycles: 1 } }
  end

  @doc """
  Conditionally jump to a label. Program counter (pc) will be set to the location of the first active label
  if the expression evaluates to true. Otherwise the pc will not be changed. If there is no active matching label,
  the pc will also be unchanged.
  """
  def jump_if(%Runner{program: program} = runner_state, [[neg, left, op, right], label]) do
    # first active matching label
    with line_number when not is_nil(line_number) <- Program.line_for(program, label),
         true <- Maths.check(neg, _resolve_variable(runner_state, left), op, _resolve_variable(runner_state, right)) do
      %{ runner_state | program: %{program | pc: line_number, lc: 0} }
    else
      _ -> runner_state
    end
  end
  def jump_if(%Runner{} = runner_state, [[left, op, right], label]) do
    jump_if(runner_state, [["", left, op, right], label])
  end
  def jump_if(%Runner{} = runner_state, [[neg, left], label]) do
    jump_if(runner_state, [[neg, left, "==", true], label])
  end
  def jump_if(%Runner{} = runner_state, [left, label]) do
    jump_if(runner_state, [["", left, "==", true], label])
  end

  defp _resolve_variable(%Runner{} = runner_state, {type, var, concat}) do
    resolved_variable = _resolve_variable(runner_state, {type, var})
    if is_binary(resolved_variable) do
      resolved_variable <> concat
    else
      resolved_variable
    end
  end
  defp _resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :color}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.color
  end
  defp _resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :background_color}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.background_color
  end
  defp _resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :name}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.name
  end
  defp _resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, var}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.parsed_state[var]
  end
  defp _resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, var}) do
    event_sender && event_sender.parsed_state[var]
  end
  defp _resolve_variable(%Runner{state: state}, {:instance_state_variable, var}) do
    state.state_values[var]
  end
  defp _resolve_variable(%Runner{state: state, object_id: object_id}, {{:direction, direction}, var}) do
    base = Instances.get_map_tile_by_id(state, %{id: object_id})
    object = Instances.get_map_tile(state, base, direction)
    object && object.parsed_state[var]
  end
  defp _resolve_variable(%Runner{}, literal) do
    literal
  end

  @doc """
  Locks the object. This will prevent it from receiving and acting on any
  message/event until it is unlocked. The underlying state value `locked`
  can also be directly set via the state shorthand `@`.

  ## Examples

    iex> Command.lock(%Runner{}, [])
    %Runner{program: program,
            object_id: object_id,
            state: %Instances{by_map_ids: %{object_id => %{ object | state: "locked: true"} }} }
  """
  def lock(runner_state, _) do
    change_state(runner_state, [:locked, "=", true])
  end

  @doc """
  Moves the associated map tile/object based in the direction given by the first parameter.
  If the second parameter is `true` then the command will retry until the object is able
  to complete the move (unless the program also responds to THUD). When `false` (or not present)
  it will attempt once, and then move on with the next instruction.

  If the movement is invalid, the `pc` will be set to the location of the `THUD` label if an active one exists.

  A succesful movement will also set the objects `facing` state value to that direction.

  Valid directions:
  north    - up
  south    - down
  east     - right
  west     - left
  idle     - no movement
  continue - continue in the current direction of the `facing` state value. Acts as `idle` if this value is not set or valid.

  ## Examples

    iex> Command.move(%Runner{program: %Program{},
                              object_id: object_id,
                              state: state},
                      ["n", true])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Instances{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def move(%Runner{program: program, object_id: object_id, state: state} = runner_state, ["idle", _]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    %{ runner_state | program: %{program | status: :wait, wait_cycles: StateValue.get_int(object, :wait_cycles, 5) } }
  end
  def move(%Runner{} = runner_state, [direction]) do
    move(runner_state, [direction, false])
  end
  def move(%Runner{program: program} = runner_state, [direction, retry_until_successful]) do
    next_actions = %{pc: program.pc, lc: 0, invalid_move_handler: &_invalid_simple_command/2}
    _move(runner_state, direction, retry_until_successful, next_actions)
  end

  defp _move(runner_state, "player", retryable, next_actions) do
    {new_runner_state, player_direction} = _direction_of_player(runner_state)
    _move(new_runner_state, player_direction, retryable, next_actions)
  end
  defp _move(%Runner{program: program, object_id: object_id, state: state} = runner_state, "idle", _retryable, next_actions) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    %{ runner_state | program: %{program | pc: next_actions.pc,
                                                 lc: next_actions.lc,
                                                 status: :wait,
                                                 wait_cycles: StateValue.get_int(object, :wait_cycles, 5) }}
  end
  defp _move(%Runner{object_id: object_id, state: state} = runner_state, direction, retryable, next_actions) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)

    destination = Instances.get_map_tile(state, object, direction)

    # Might want to be able to pass coordinates, esp if the movement will ever be more than one away
    runner_state = send_message(runner_state, ["touch", direction])
    %Runner{program: program, state: state} = runner_state
# TODO: does the object really need refreshed here?
    case Move.go(object, destination, state) do
      {:ok, tile_changes, new_state} ->

        message = ["tile_changes",
                   %{tiles: tile_changes
                            |> Map.to_list
                            |> Enum.map(fn({_coords, tile}) ->
                              Map.put(Map.take(tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
                            end)}]

        updated_runner_state = %Runner{ runner_state |
                                        program: %{program | pc: next_actions.pc,
                                                             lc: next_actions.lc,
                                                             broadcasts: [message | program.broadcasts],
                                                             status: :wait,
                                                             wait_cycles: object.parsed_state[:wait_cycles] || 5 },
                                        state: new_state}

        change_state(updated_runner_state, [:facing, "=", direction])

      {:invalid} ->
        next_actions.invalid_move_handler.(runner_state, retryable)
    end
  end

  defp _get_real_direction(object, {:state_variable, var}) do
    object.parsed_state[var] || "idle"
  end
  defp _get_real_direction(object, "continue") do
    object.parsed_state[:facing] || "idle"
  end
  defp _get_real_direction(_object, direction), do: direction

  defp _invalid_compound_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, retryable) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, :wait_cycles, 5)
    cond do
      line_number = Program.line_for(program, "THUD") ->
          %{ runner_state | program: %{program | pc: line_number, lc: 0, status: :wait, wait_cycles: wait_cycles} }
      retryable ->
          %{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: wait_cycles} }
      true ->
          %{ runner_state | program: %{program | pc: program.pc - 1, lc: program.lc + 1,  status: :wait, wait_cycles: wait_cycles} }
    end
  end

  defp _invalid_simple_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, retryable) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, :wait_cycles, 5)
    cond do
      line_number = Program.line_for(program, "THUD") ->
          %{ runner_state | program: %{program | pc: line_number, status: :wait, wait_cycles: wait_cycles} }
      retryable ->
          %{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: wait_cycles} }
      true ->
          %{ runner_state | program: %{program | status: :wait, wait_cycles: wait_cycles} }
    end
  end

  @doc """
  Non operation. Returns unaltered parameters.

  ## Examples

    iex> Command.noop(%Runner{})
    %Runner{}
  """
  def noop(%Runner{} = runner_state, _ignored \\ nil) do
    runner_state
  end

  @doc """
  Restores a disabled ('zapped') label. This will allow it to be used when an event
  is sent to the object/program. Nothing is done if all labels that match the given one
  are active. Reactivates labels prioritizing the one closer to the end of the script.

  ## Examples

    iex> Command.restore(%Runner{}, ["thud"])
    %Runner{}
  """
  def restore(%Runner{program: program} = runner_state, [label]) do
    with normalized_label <- String.downcase(label),
         labels when not is_nil(labels) <- program.labels[normalized_label] do
      restored = labels
                 |> Enum.reverse()
                 |> _label_toggle(false)
                 |> Enum.reverse()
      if restored == labels do
        runner_state
      else
        updated_program = %{ program | labels: Map.put(program.labels, normalized_label, restored)}
        %{ runner_state | program: updated_program }
      end
    else
      _ -> runner_state
    end
  end

  @doc """
  Sends a message. A message can be sent to the current running program, or to another program.
  The first parameter is the message to send, and the second (optional) param is the target.
  Both the label and the name are case insensitive.

  Valid targets are:

  `all` - all running programs, including this one
  `others` - all other progograms
  a direction - ie, north, south east, west
  the name of a tile

  The target will be resolved in the above order. A tile that shares one of the reserved words
  (ie, all, other, north, south, east, west, self, etc) as its name will not necessarily be resolved
  as the target. Naming a tile `north` and sending a message with `north` as the target will send
  it to the tile north of the program's tile, not to tiles named `north`.

  State values can be used as a target, by using `@` followed by the state attribute as the string.
  If there is no matching attribute, or the attribute is invalid, no message will be sent.
  ie, "@facing" will use whatever is stored as the program object's facing.

  The specail varialble `?sender` can be used to send the message to the program
  that sent the event.
  """
  def send_message(%Runner{} = runner_state, [label]), do: _send_message(runner_state, [label, "self"])
  def send_message(%Runner{object_id: object_id, state: state} = runner_state, [label, {:state_variable, var}]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    _send_message(runner_state, [label, object.parsed_state[var]])
  end
  def send_message(%Runner{event_sender: event_sender} = runner_state, [label, [:event_sender]]) do
    case event_sender do
      %{map_tile_id: id} -> _send_message_via_ids(runner_state, label, [id]) # basic tile
      %{map_tile_instance_id: id} -> _send_message_via_ids(runner_state, label, [id]) # player tile
      # Right now, if the actor was a player, this does nothing. Might change later.
      _                  -> runner_state
    end
  end
  def send_message(%Runner{} = runner_state, [label, target]) do
    _send_message(runner_state, [label, String.downcase(target)])
  end
  defp _send_message(%Runner{state: state, object_id: object_id} = runner_state, [label, "self"]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    %{ runner_state | state: %{ state | program_messages: [ {object.id, label, %{map_tile_id: object.id, parsed_state: object.parsed_state}} |
                                                            state.program_messages] } }
  end
  defp _send_message(%Runner{state: state, object_id: object_id} = runner_state, [label, "others"]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    _send_message_id_filter(runner_state, label, fn object_id -> object_id != object.id end)
  end
  defp _send_message(%Runner{} = runner_state, [label, "all"]) do
    _send_message_id_filter(runner_state, label, fn _object_id -> true end)
  end
  defp _send_message(%Runner{state: state} = runner_state, [label, target]) do
    if target in ["north", "up", "south", "down", "east", "right", "west", "left"] do
      _send_message_in_direction(runner_state, label, target)
    else
      map_tile_ids = state.map_by_ids
                     |> Map.to_list
                     |> Enum.filter(fn {_id, tile} -> String.downcase(tile.name || "") == target end)
                     |> Enum.map(fn {id, _tile} -> id end)
      _send_message_via_ids(runner_state, label, map_tile_ids)
    end
  end

  defp _send_message_in_direction(%Runner{state: state, object_id: object_id} = runner_state, label, direction) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    map_tile_ids = Instances.get_map_tiles(state, object, direction)
                   |> Enum.map(&(&1.id))
    _send_message_via_ids(runner_state, label, map_tile_ids)
  end

  defp _send_message_id_filter(%Runner{state: state} = runner_state, label, filter) do
    program_object_ids = state.program_contexts
                         |> Map.keys()
                         |> Enum.filter(&filter.(&1))
    _send_message_via_ids(runner_state, label, program_object_ids)
  end

  defp _send_message_via_ids(runner_state, _label, []), do: runner_state
  defp _send_message_via_ids(%Runner{state: state, object_id: object_id} = runner_state, label, [po_id | program_object_ids]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    _send_message_via_ids(
      %{ runner_state | state: %{ state | program_messages: [ {po_id, label, %{map_tile_id: object_id, parsed_state: object.parsed_state}} |
                                                              state.program_messages] } },
      label,
      program_object_ids
    )
  end

  @doc """
  Fires a bullet in the given direction. The bullet will spawn on the tile one away from the object
  in the direction, unless that tile is blocking or responds to "SHOT", in which case that tile
  will be sent the "SHOT" message and no bullet will spawn.
  Otherwise, the bullet will walk in given direction until it hits something, or something
  responds to the "SHOT" message.
  """
  def shoot(%Runner{state: state, object_id: object_id} = runner_state, [{:state_variable, var}]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    shoot(runner_state, [object.parsed_state[var]])
  end
  def shoot(%Runner{object_id: object_id, state: state} = runner_state, [direction]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)

    case Shoot.shoot(object, direction, state) do
      {:invalid} ->
        runner_state

      {:ok, updated_state} ->
        %{ runner_state | state: updated_state }
    end
  end

  @doc """
  Take from a tile an amount of something. This modifies the state of that tile by subtracting the amount from
  whatever is at that key is at (creating it if not already present). If there is not enough to take, nothing is taken
  and optionally a label can be given to continue at. First parameter is `what` (the
  state field, ie `ammo`), second the quantity (must be a positive number). Quantity may reference a state
  value for the giving tile. Third is the losing tile of it. Fourth, optional, is the label to have the program use
  if the target tile does not have enough to take.

  Valid tiles can be a direction - ie, north, south east, west; additionally
  the special varialble `?sender` can be used to give to the program/player
  that sent the last event. For example, if a player touches a certain object,
  that object could give them gems.

  ## Examples

    iex> Command.take(%Runner{}, [:cash, :420, [:event_sender], "toopoor"])
    %Runner{}
    iex> Command.take(%Runner{}, [:ammo, {:state_variable, :rounds}, "north"])
    %Runner{}
  """
  def take(%Runner{} = runner_state, [what, amount, to_whom]) do
    _take(runner_state, what, amount, to_whom, nil)
  end
  def take(%Runner{} = runner_state, [what, amount, to_whom, label]) do
    _take(runner_state, what, amount, to_whom, label)
  end

  defp _take(%Runner{event_sender: event_sender} = runner_state, what, amount, [:event_sender], label) do
    case event_sender do
      %{map_tile_id: id} -> _take(runner_state, what, amount, id, label)

      %Location{map_tile_instance_id: id} -> _take(runner_state, what, amount, id, label)

      nil              -> runner_state
    end
  end

  defp _take(%Runner{} = runner_state, what, amount, id, label) when is_integer(id) do
    _take_via_id(runner_state, what, amount, id, label)
  end

  defp _take(%Runner{object_id: object_id, state: state} = runner_state, what, amount, direction, label) do
    with direction when direction in ["north", "up", "south", "down", "east", "right", "west", "left"] <- direction,
         object when not is_nil(object) <- Instances.get_map_tile_by_id(state, %{id: object_id}),
         map_tile when not is_nil(map_tile) <- Instances.get_map_tile(state, object, direction) do
      _take(runner_state, what, amount, map_tile.id, label)
    else
      _ ->
        runner_state
    end
  end

  defp _take_via_id(%Runner{object_id: object_id, state: state, event_sender: sender} = runner_state, what, amount, id, label) do
    amount = _resolve_variable(runner_state, amount)
    what = _resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      what = String.to_atom(what)
      receiver = Instances.get_map_tile_by_id(state, %{id: id})
      new_value = (receiver.parsed_state[what] || 0) - amount

      cond do
        new_value >= 0 ->
          {_receiver, state} = Instances.update_map_tile_state(state, receiver, %{what => new_value})

          if state.player_locations[id] do
            payload = %{stats: PlayerInstance.current_stats(state, %DungeonCrawl.DungeonInstances.MapTile{id: id})}
            %{ runner_state | program: %{runner_state.program | responses: [ {"stat_update", payload} | runner_state.program.responses] }, state: state }
          else
            %{ runner_state | state: state }
          end

        label && sender ->
          state = %{ state | program_messages: [ {object_id, label, sender} | state.program_messages] }
          %{ runner_state | state: state, program: state.program_contexts[object_id].program }

        true ->
          runner_state
      end
    else
      runner_state
    end
  end


  @doc """
  Kills the script for the object. Returns a dead program, and deletes the script from the object (map_tile instance).

  ## Examples

    iex> Command.terminate(%Runner{program: program,
                                   object_id: object_id,
                                   state: %Instances{ map_by_ids: %{object_id => %{ script: "..." } } }}
    %Runner{program: %{program | pc: -1, status: :dead},
            state: %Instances{ map_by_ids: %{object_id => %{ script: "" } } }}
  """
  def terminate(%Runner{program: program, object_id: object_id, state: state} = runner_state, _ignored \\ nil) do
    {_updated_object, updated_state} = Instances.update_map_tile(state, %{id: object_id}, %{script: ""})
    %{ runner_state |
       program: %{program | status: :dead, pc: -1},
       state: updated_state}
  end


  @doc """
  Adds text to the responses for showing to a player in particular (ie, one who TOUCHed the object).

  ## Examples

    iex> Command.text(%Runner{program: program}, params: ["Door opened"])
    %Runner{ program: %{program | responses: ["Door opened"]} }
  """
  def text(%Runner{program: program} = runner_state, params) do
    if params != [""] do
      # TODO: probably allow this to be refined by whomever the message is for
      message = Enum.map(params, fn(param) -> String.trim(param) end) |> Enum.join("\n")
      %{ runner_state | program: %{program | responses: [ {"message", %{message: message}} | program.responses] } }
    else
      runner_state
    end
  end

  @doc """
  Attempt to move in the given direction, if blocked the object doesn't move but the `THUD` message
  will still be sent.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.try(%Runner{program: %Program{},
                             object_id: object_id,
                             state: state},
                     ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Instances{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def try(runner_state, [direction]) do
    move(runner_state, [direction, false])
  end

  @doc """
  Locks the object. This will prevent it from receiving and acting on any
  message/event until it is unlocked. The underlying state value `locked`
  can also be directly set via the state shorthand `@`.

  ## Examples

    iex> Command.unlock(%Runner{}, [])
    %Runner{program: program,
            state: %Instances{map_by_ids: %{ object | state: "locked: false" } }}
  """
  def unlock(runner_state, _) do
    change_state(runner_state, [:locked, "=", false])
  end

  @doc """
  Continue to move in the given direction until bumping into something. Similar to `TRY` but repeats until
  it cannot move in the given direction anymore.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.try(%Runner{program: %Program{},
                             object_id: object_id,
                             state: state},
                     ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5, pc: pc - 1 },
            state: %Instances{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def walk(%Runner{program: program} = runner_state, [direction]) do
    next_actions = %{pc: program.pc - 1, lc: 0, invalid_move_handler: &_invalid_simple_command/2}
    _move(runner_state, direction, false, next_actions)
  end

  defp _direction_of_player(%Runner{object_id: object_id, state: state} = runner_state) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    target_player_map_tile_id = StateValue.get_int(object, :target_player_map_tile_id)
    _direction_of_player(runner_state, target_player_map_tile_id)
  end
  defp _direction_of_player(%Runner{state: state} = runner_state, nil) do
    with map_tile_ids when length(map_tile_ids) != 0 <- Map.keys(state.player_locations),
         player_map_tile_id <- Enum.random(map_tile_ids) do

      _direction_of_player(change_state(runner_state, [:target_player_map_tile_id, "=", player_map_tile_id]))
    else
      _ -> {change_state(runner_state, [:target_player_map_tile_id, "=", nil]), "idle"}
    end
  end
  defp _direction_of_player(%Runner{state: state, object_id: object_id} = runner_state, target_player_map_tile_id) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    with player_map_tile when player_map_tile != nil <- Instances.get_map_tile_by_id(state, %{id: target_player_map_tile_id}) do
      {runner_state, Instances.direction_of_map_tile(state, object, player_map_tile)}
    else
      _ ->
      _direction_of_player(change_state(runner_state, [:target_player_map_tile_id, "=", nil]))
    end
  end

  @doc """
  Disables a label. This will prevent the label from being used to change the pc when
  the program/object recieves an event. Nothing is done if all labels that match the
  given one are inactive. Disables labels prioritizing the one closer to the top of the script.

  ## Examples

    iex> Command.zap(%Runner{}, ["thud"])
    %Runner{}
  """
  def zap(%Runner{program: program} = runner_state, [label]) do
    with normalized_label <- String.downcase(label),
         labels when not is_nil(labels) <- program.labels[normalized_label] do
      zapped = labels
               |> _label_toggle(true)
      if zapped == labels do
        runner_state
      else
        updated_program = %{ program | labels: Map.put(program.labels, normalized_label, zapped)}
        %{ runner_state | program: updated_program }
      end
    else
      _ -> runner_state
    end
  end

  defp _label_toggle([], _), do: []
  defp _label_toggle([ [line_number, active] | labels ], toggle_value) do
    if active == toggle_value do
      [ [line_number, !active] | labels]
    else
      [ [line_number, active] | _label_toggle(labels, toggle_value)]
    end
  end
end
