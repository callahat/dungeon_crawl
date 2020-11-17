defmodule DungeonCrawl.Scripting.Command do
  @moduledoc """
  The various scripting commands available to a program.
  """

  alias DungeonCrawl.Action.{Move, Pull, Shoot, Travel}
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Maths
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Shape
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  import DungeonCrawl.Scripting.VariableResolution, only: [resolve_variable_map: 2, resolve_variable: 2]
  import Direction, only: [is_valid_orthogonal_change: 1, is_valid_orthogonal: 1]

  import Phoenix.HTML, only: [html_escape: 1]

  require Logger

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
      :change_other_state -> :change_other_state
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
      :passage      -> :passage
      :pull         -> :pull
      :push         -> :push
      :put          -> :put
      :random       -> :random
      :replace      -> :replace
      :remove       -> :remove
      :restore      -> :restore
      :send         -> :send_message
      :sequence     -> :sequence
      :shift        -> :shift
      :shoot        -> :shoot
      :take         -> :take
      :target_player -> :target_player
      :terminate    -> :terminate
      :text         -> :text
      :transport    -> :transport
      :try          -> :try
      :unlock       -> :unlock
      :walk         -> :walk
      :zap          -> :zap

      _ -> nil
    end
  end

  @doc """
  Transforms the object refernced by the id in some way. Changes can include character, color, background color.
  Additionally, if given a `slug`, the tile will be replaced with the matching tile template corresponding to the
  given slug. Other changes given, such as character, color, background color, will override the values from
  the matching tile template. Other values not mentioned above will set state values.
  Just changing the tile_template_id does not copy all other attributes of that tile template to the object.
  Reference variables can be used instead of literals; however if they resolve to invalid values, then
  this command will do nothing.

  Changes will be persisted to the database, and the coordinates will be marked for rerendering.

  ## Examples

    iex> Command.become(%Runner{}, [%{character: $}])
    %Runner{program: %{program |
            object_id: object_id,
            state: updated_state }
  """
  def become(%Runner{} = runner_state, [{:ttid, ttid}]) do
    tile_template = TileTemplates.get_tile_template!(ttid)
    Logger.warn "DEPRECATION - BECOME command used `TTID:#{ttid}`, replace this with `slug: #{tile_template.slug}`"
    new_attrs = Map.take(tile_template, [:character, :color, :background_color, :state, :script])
    _become(runner_state, Map.put(new_attrs, :tile_template_id, ttid), %{})
  end
  def become(%Runner{} = runner_state, [params]) do
    slug_tile = TileTemplates.get_tile_template_by_slug(params[:slug])
    new_attrs = if slug_tile do
                  Map.take(slug_tile, [:character, :color, :background_color, :state, :script, :name])
                  |> Map.put(:tile_template_id, slug_tile.id)
                else
                  %{}
                end
                |> Map.merge(Map.take(params, [:character, :color, :background_color]))
    new_state_attrs = Map.take(params, Map.keys(params) -- (Map.keys(%TileTemplates.TileTemplate{}) ++ [:slug]))
    _become(runner_state, new_attrs, new_state_attrs)
  end
  def _become(%Runner{program: program, object_id: object_id, state: state} = runner_state, new_attrs, new_state_attrs) do
    new_attrs = resolve_variable_map(runner_state, new_attrs)
    new_state_attrs = resolve_variable_map(runner_state, new_state_attrs)

    object = Instances.get_map_tile_by_id(state, %{id: object_id})

    case DungeonCrawl.DungeonInstances.MapTile.changeset(object, new_attrs).valid? do
      true -> # all that other stuff below
        {object, state} = Instances.update_map_tile(
                          state,
                          %{id: object_id},
                          new_attrs)
        {object, state} = Instances.update_map_tile_state(
                          state,
                          object,
                          new_state_attrs)

        current_program = cond do
                            is_nil(Map.get(state.program_contexts, object.id)) ->
                              %{ program | status: :dead }
                            Map.has_key?(new_attrs, :script) ->
                              # A changed script will update the program, so get the current
                              %{ Map.get(state.program_contexts, object.id).program | pc: 0, lc: 0, status: :wait }
                            true ->
                              program
                          end

        %{ runner_state |
             program: %{current_program | responses: program.responses },
             state: state }

      false ->
        runner_state
    end
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
  def change_state(%Runner{object_id: object_id} = runner_state, [var, op, value]) do
    value = resolve_variable(runner_state, value)
    _change_state(runner_state, object_id, var, op, value)
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
  Changes the state_value for an object given in the params. The target object can be specified by
  a direction (relative from the current object) or by a map tile id. Not valid against player tiles.

  ## Examples

    iex> Command.change_other_state(%Runner{program: program,
                                               state: %Instances{state_values: %{}}},
                                       ["north", :space, "=", 3])
    %Runner{program: program,
            state: %Instances{map_by_ids: %{1 => %{state: "space: 3"},...}, ...} }
  """
  def change_other_state(%Runner{} = runner_state, [target, var, op, value]) do
    target = resolve_variable(runner_state, target)
    value = resolve_variable(runner_state, value)

    _change_state(runner_state, target, var, op, value)
  end

  def _change_state(%Runner{state: state} = runner_state, %{} = target, var, op, value) do
    if(target.parsed_state[:player]) do
      runner_state
    else
      update_var = %{ var => Maths.calc(target.parsed_state[var] || 0, op, value) }
      {_updated_target, updated_state} = Instances.update_map_tile_state(state, target, update_var)
      %Runner{ runner_state | state: updated_state }
    end
  end

  def _change_state(%Runner{object_id: object_id, state: state} = runner_state, target, var, op, value) when is_binary(target) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    target_tile = Instances.get_map_tile(state, object, target)
    _change_state(runner_state, target_tile, var, op, value)
  end

  def _change_state(%Runner{state: state} = runner_state, target, var, op, value) when is_integer(target) do
    target_tile = Instances.get_map_tile_by_id(state, %{id: target})
    _change_state(runner_state, target_tile, var, op, value)
  end

  def _change_state(%Runner{} = runner_state, _, _, _, _) do
    runner_state
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
        next_actions = %{pc: program.pc - 1, lc: program.lc + 1, invalid_move_handler: &_invalid_compound_command/3}
        _move(runner_state, direction, retry_until_successful, next_actions, &Move.go/3)
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
            state: %Instances{ map_by_ids: %{object_id => %{ object | state: "wait_cycles: 1" } } } }
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
    {_deleted_object, updated_state} = Instances.delete_map_tile(state, %{id: object_id})

    %Runner{runner_state |
            program: %{program | status: :dead, pc: -1},
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
    if Direction.valid_orthogonal?(direction) do
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

  defp _give_via_id(%Runner{state: state, program: program} = runner_state, [what, amount, [id], max, label]) do
    amount = resolve_variable(runner_state, amount)
    what = resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      max = resolve_variable(runner_state, max)
      receiver = Instances.get_map_tile_by_id(state, %{id: id})
      what = String.to_atom(what)
      current_value = receiver && receiver.parsed_state[what] || 0
      adjusted_amount = _adjust_amount_to_give(amount, max, current_value)
      new_value = current_value + adjusted_amount

      cond do
        receiver && adjusted_amount > 0 ->
          {_receiver, state} = Instances.update_map_tile_state(state, receiver, %{what => new_value})

          if state.player_locations[id] do
            payload = %{stats: PlayerInstance.current_stats(state, %DungeonCrawl.DungeonInstances.MapTile{id: id})}
            %{ runner_state | program: %{runner_state.program | responses: [ {"stat_update", payload} | runner_state.program.responses] }, state: state }
          else
            %{ runner_state | state: state }
          end

        is_number(max) && label ->
          updated_program = %{ runner_state.program | pc: Program.line_for(program, label), status: :wait, wait_cycles: 1 }
          %{ runner_state | state: state, program: updated_program }

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
  reverse, clockwise, or counterclockwise is specified. player will cause the object
  to face the player it is targeting (a player will be picked to target if it is not
  already targeting one - state value at "target_player_map_tile_id").

  north, up
  south, down
  east, right
  west, left
  reverse - reverses the current facing direction (ie, north becomes south)
  clockwise - turns the current facing clockwise (ie, north becomes west)
  counterclockwise - turns the current facing counter clockwise (ie, north becomes east)
  player - faces the player it is targeting

  ## Examples

    iex> Command.facing(%Runner{program: program, state: state}, ["player"])
    iex> Command.facing(%Runner{program: program, state: state}, ["reverse"])
  """
  def facing(%Runner{} = runner_state, ["player"]) do
    {new_runner_state, player_direction} = _direction_of_player(runner_state)
    _facing(new_runner_state, player_direction)
  end
  def facing(%Runner{} = runner_state, [direction]) when is_tuple(direction) do
    direction = resolve_variable(runner_state, direction)
    facing(runner_state, [direction])
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, [change]) when is_valid_orthogonal_change(change) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = Direction.change_direction(object.parsed_state[:facing], change)
    _facing(runner_state, direction)
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, [tile_id]) when is_integer(tile_id) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    if target = Instances.get_map_tile_by_id(state, %{id: tile_id}) do
      _facing(runner_state, Instances.direction_of_map_tile(state, object, target))
    else
      runner_state
    end
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

  When no label is given, or an integer is given instead, if the expression is false, then the following N instruction(s)
  will be skipped over. This is useful for when you want to conditionally skip over the next N instruction(s).
  """
  def jump_if(%Runner{} = runner_state, [check]) do
    jump_if(runner_state, [check, 1])
  end
  def jump_if(%Runner{} = runner_state, [[neg, left, op, right], label]) do
    check = Maths.check(neg, resolve_variable(runner_state, left), op, resolve_variable(runner_state, right))
    _jump_if(runner_state, check, label)
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

  defp _jump_if(%Runner{program: program} = runner_state, true, label) when is_binary(label) do
    # TODO: look into having this send the label, since all messages will get processed (might only do up to 10 messages
    #       to prevent infinite loops from crashing the instance.
    if line_number = Program.line_for(program, label)  do
      %{ runner_state | program: %{program | pc: line_number, lc: 0} }
    else
      runner_state
    end
  end
  defp _jump_if(%Runner{program: program} = runner_state, false, skip) when is_integer(skip) do
    %{ runner_state | program: %{program | pc: program.pc + skip, lc: 0} }
  end
  defp _jump_if(%Runner{} = runner_state, _, _), do: runner_state

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
  player   - move in the direction of the player

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
    next_actions = %{pc: program.pc, lc: 0, invalid_move_handler: &_invalid_simple_command/3}
    _move(runner_state, direction, retry_until_successful, next_actions, &Move.go/3)
  end

  defp _move(runner_state, direction, retryable, next_actions, move_func) when is_tuple(direction) do
    direction = resolve_variable(runner_state, direction)
    _move(runner_state, direction, retryable, next_actions, move_func)
  end
  defp _move(runner_state, "player", retryable, next_actions, move_func) do
    {new_runner_state, player_direction} = _direction_of_player(runner_state)
    _move(new_runner_state, player_direction, retryable, next_actions, move_func)
  end
  defp _move(%Runner{program: program, object_id: object_id, state: state} = runner_state, "idle", _retryable, next_actions, _) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    %{ runner_state | program: %{program | pc: next_actions.pc,
                                                 lc: next_actions.lc,
                                                 status: :wait,
                                                 wait_cycles: StateValue.get_int(object, :wait_cycles, 5) }}
  end
  defp _move(%Runner{object_id: object_id, state: state} = runner_state, direction, retryable, next_actions, move_func) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)

    destination = Instances.get_map_tile(state, object, direction)

    # Might want to be able to pass coordinates, esp if the movement will ever be more than one away
    runner_state = send_message(runner_state, ["touch", direction])
    %Runner{program: program, state: state} = runner_state

    case move_func.(object, destination, state) do
      {:ok, _tile_changes, new_state} ->
        updated_runner_state = %Runner{ runner_state |
                                        program: %{program | pc: next_actions.pc,
                                                             lc: next_actions.lc,
                                                             status: :wait,
                                                             wait_cycles: object.parsed_state[:wait_cycles] || 5 },
                                        state: new_state}
        change_state(updated_runner_state, [:facing, "=", direction])

      {:invalid} ->
        next_actions.invalid_move_handler.(runner_state, destination, retryable)
    end
  end

  defp _get_real_direction(object, {:state_variable, var}) do
    object.parsed_state[var] || "idle"
  end
  defp _get_real_direction(object, "continue") do
    object.parsed_state[:facing] || "idle"
  end
  defp _get_real_direction(_object, direction), do: direction || "idle"

  defp _invalid_compound_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, blocking_obj, retryable) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, :wait_cycles, 5)
    cond do
      Program.line_for(program, "THUD") ->
        sender = if blocking_obj, do: %{map_tile_id: blocking_obj.id, parsed_state: blocking_obj.parsed_state, name: blocking_obj.name},
                                  else: %{map_tile_id: nil, parsed_state: %{}}
        program = %{program | status: :wait, wait_cycles: wait_cycles}
        %{ runner_state |
             program: Program.send_message(program, "THUD", sender) }

      retryable ->
          %{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: wait_cycles} }
      true ->
          %{ runner_state | program: %{program | pc: program.pc - 1, lc: program.lc + 1,  status: :wait, wait_cycles: wait_cycles} }
    end
  end

  defp _invalid_simple_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, blocking_obj, retryable) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, :wait_cycles, 5)
    cond do
      Program.line_for(program, "THUD") ->
        sender = if blocking_obj, do: %{map_tile_id: blocking_obj.id, parsed_state: blocking_obj.parsed_state, name: blocking_obj.name},
                                  else: %{map_tile_id: nil, parsed_state: %{}}
        program = %{program | status: :wait, wait_cycles: wait_cycles}
        %{ runner_state |
             program: Program.send_message(program, "THUD", sender) }

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
  Registers the map tile as a passage exit. Parameter is the passage identifier that will be used to find
  it when the TRANSPORT command is invoked. The parameter can be a literal value, or it can be a state variable
  such as the objects color.

  ## Examples

    iex> Command.passage(%Runner{object_id: object_id}, [{:state_variable, :background_color}])
    %Runner{ state: %Instances{..., passage_exits: [{object_id, {:state_variable, :background_color}}] } }

    iex> Command.passage(%Runner{object_id: object_id}, ["door1"])
    %Runner{ state: %Instances{..., passage_exits: [{object_id, "door1"}] } }
  """
  def passage(%Runner{state: state, object_id: object_id} = runner_state, [match_key]) do
    match_key = resolve_variable(runner_state, match_key)
    %{ runner_state | state: %{ state | passage_exits: [ {object_id, match_key} | state.passage_exits] } }
  end

  @doc """
  Similar to the TRY command. The main difference is that the object will pull an adjacent map tile into its
  previous location if able. If the pulled tile has the state value `pulling` set then that tile may also pull an
  adjacent tile to where it was (this can be chained).

  See the `move` command for valid directions.

  ## Examples

    iex> Command.pull(%Runner{program: %Program{},
                              object_id: object_id,
                              state: state},
                      ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Instances{ map_by_ids: %{object_id => %{object | row: object.row - 1},
                                             pulled_object_id => %{pulled_object | row: object.row } } }}
  """
  def pull(%Runner{} = runner_state, [direction]) do
    pull(runner_state, [direction, false])
  end
  def pull(%Runner{program: program} = runner_state, [direction, retry_until_successful]) do
    next_actions = %{pc: program.pc, lc: 0, invalid_move_handler: &_invalid_simple_command/3}
    _move(runner_state, direction, retry_until_successful, next_actions, &Pull.pull/3)
  end

  @doc """
  Pushes a nearby (or above) tile in the given direction if that tile hash the `pushable` standard behavior.
  Tiles may be pushed up to the given `range` (default of 1) away. For example, a pushable tile immediately to the
  west would be pushed one more space to the west when `direction` is west and `range` is one.
  A tile in range will be pushed up to one space for each invocation of a push method.

  ## Examples

    iex> Command.push(%Runner{}, ["north"])
    iex> Command.push(%Runner{}, ["west", 3])
  """
  def push(%Runner{} = runner_state, [direction]) do
    push(runner_state, [direction, 1])
  end

  def push(%Runner{object_id: object_id, state: state} = runner_state, [direction, range]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)
    range = resolve_variable(runner_state, range)

    {row_d, col_d} = Direction.delta(direction)

    _push(runner_state, object, direction, {row_d, col_d}, range)
  end

  defp _push(%Runner{state: state} = runner_state, object, direction, {row_d, col_d}, range) when range >= 0 do
    case Instances.get_map_tiles(state, %{row: object.row + row_d * range, col: object.col + col_d * range}) do
      nil ->
        _push(runner_state, object, direction, {row_d, col_d}, range - 1)

      pushees ->
        Enum.reduce(pushees, runner_state, fn(pushee, runner_state) ->
          case pushee.parsed_state[:pushable] &&
               pushee.id != object.id &&
               Move.go(pushee, Instances.get_map_tile(state, pushee, direction), state) do
            {:ok, _tile_changes, new_state} ->
              %Runner{ runner_state | state: new_state}

            _ ->
              runner_state
          end
        end)
        |> _push(object, direction, {row_d, col_d}, range - 1)
    end
  end

  defp _push(runner_state, _, _, _, _), do: runner_state

  @doc """
  Puts a new tile specified by the given `slug` in the given `direction`. If no `direction` is given, then the new tile
  is placed on top of the tile associated with the running script.

  Alternatively, instead of putting a slug, an existing tile may be used instead, by using `clone` and the id
  of the tile to use as a base (or just a straight up clone). If there is a script on the cloned tile, the script
  will start from the top (and not where the script is currently executing on the original tile).

  Additionally, instead of a direction, `row` and `col` coordinates can be supplied to put the tile in a specific
  location. Direction can also be given to put the tile one square from the given coordinates in that direction.
  If both `row` and `col` are not given, then neither are used. If the specified location or direction is invalid/off the map,
  then nothing is done.
  Other kwargs can be given, such as character, color, background color, and will override the values from
  the matching tile template. Other values not mentioned above will set state values.
  Reference variables can be used instead of literals; however if they resolve to invalid values, then
  this command will do nothing.

  Changes will be persisted to the database, and that coordinate will be marked for rerendering.

  ## Examples

    iex> Command.put(%Runner{}, [%{slug: "banana", direction: "north"}])
    %Runner{program: %{program |
            object_id: object_id,
            state: updated_state }
    iex> Command.put(%Runner{}, [%{clone:  {:state_variable, :clone_id}, direction:  {:state_variable, :facing}}])
    %Runner{}
  """
  def put(%Runner{state: state} = runner_state, [%{clone: clone_tile} = params]) do
    params = resolve_variable_map(runner_state, params)
    clone_tile = resolve_variable(runner_state, clone_tile)
    clone_base_tile = Instances.get_map_tile_by_id(state, %{id: clone_tile})

    if clone_base_tile do
      attributes = Map.take(clone_base_tile, [:character, :color, :background_color, :state, :script, :name, :tile_template_id])
                   |> Map.merge(resolve_variable_map(runner_state, Map.take(params, [:character, :color, :background_color])))
      new_state_attrs = resolve_variable_map(runner_state,
                                             Map.take(params, Map.keys(params) -- (Map.keys(%TileTemplate{}) ++ [:direction, :shape, :clone] )))
      _put(runner_state, attributes, params, new_state_attrs)
    else
      runner_state
    end
  end

  def put(%Runner{} = runner_state, [%{slug: _slug} = params]) do
    params = resolve_variable_map(runner_state, params)
    slug_tile = TileTemplates.get_tile_template_by_slug(params[:slug])

    if slug_tile do
      attributes = Map.take(slug_tile, [:character, :color, :background_color, :state, :script, :name])
                   |> Map.put(:tile_template_id, slug_tile.id)
                   |> Map.merge(resolve_variable_map(runner_state, Map.take(params, [:character, :color, :background_color])))
      new_state_attrs = resolve_variable_map(runner_state,
                                             Map.take(params, Map.keys(params) -- (Map.keys(%TileTemplate{}) ++ [:direction, :shape] )))

      _put(runner_state, attributes, params, new_state_attrs)
    else
      runner_state
    end
  end

  defp _put(%Runner{object_id: object_id, state: state} = runner_state, attributes, %{shape: shape} = params, new_state_attrs) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, params[:direction])
    bypass_blocking = if is_nil(params[:bypass_blocking]), do: "soft", else: params[:bypass_blocking]

    case shape do
      "line" ->
        include_origin = if is_nil(params[:include_origin]), do: false, else: params[:include_origin]
        Shape.line(runner_state, direction, params[:range], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "cone" ->
        include_origin = if is_nil(params[:include_origin]), do: false, else: params[:include_origin]
        Shape.cone(runner_state, direction, params[:range], params[:width] || params[:range], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "circle" ->
        include_origin = if is_nil(params[:include_origin]), do: true, else: params[:include_origin]
        Shape.circle(runner_state, params[:range], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "blob" ->
        include_origin = if is_nil(params[:include_origin]), do: false, else: params[:include_origin]
        Shape.blob(runner_state, params[:range], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      _ ->
        runner_state
    end
  end

  defp _put(%Runner{object_id: object_id, state: state} = runner_state, attributes, params, new_state_attrs) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, params[:direction])

    {row_d, col_d} = Direction.delta(direction)
    coords = if params[:row] && params[:col] do
               %{row: params[:row] + row_d, col: params[:col] + col_d}
             else
               %{row: object.row + row_d, col: object.col + col_d}
             end

    if coords.row > 0 && coords.row <= state.state_values[:rows] &&
       coords.col > 0 && coords.col <= state.state_values[:cols] do
      new_attrs = Map.merge(attributes, Map.put(coords, :map_instance_id, object.map_instance_id))
      _put_map_tile(runner_state, new_attrs, new_state_attrs)
    else
      runner_state
    end
  end

  defp _put_map_tile(%Runner{state: state} = runner_state, map_tile_attrs, new_state_attrs) do
    z_index = if target_tile = Instances.get_map_tile(state, map_tile_attrs), do: target_tile.z_index + 1, else: 0
    map_tile_attrs = Map.put(map_tile_attrs, :z_index, z_index)

    case DungeonCrawl.DungeonInstances.new_map_tile(map_tile_attrs) do
      {:ok, new_tile} -> # all that other stuff below
        {new_tile, state} = Instances.create_map_tile(state, new_tile)
        {_new_tile, state} = Instances.update_map_tile_state(state, new_tile, new_state_attrs)
        %{ runner_state | state: state }

      {:error, _} ->
        runner_state
    end
  end

  defp _put_shape_tiles(coords, %Runner{} = runner_state, object, attributes, new_state_attrs) do
    coords
    |> Enum.reduce(runner_state, fn({row, col}, runner_state) ->
         loc_attrs = %{row: row, col: col, map_instance_id: object.map_instance_id}
         _put_map_tile(runner_state, Map.merge(attributes, loc_attrs), new_state_attrs)
       end)
  end

  @doc """
  Sets the specified state variable to a random value from a list or range. The first parameter is the
  state variable, and the subsequent parameters can be a list of values to randomly choose from
  OR an integer range. An integer range may be specified by a low bound and a high bound
  with a hyphen in the middle (ie, 1-10). The range is inclusive, and a random integer within the
  bounds (inclusive) will be used. Both the list and the range have a uniform distribution.

  ## Examples

    iex> Command.random(%Runner{}, ["foo", "1-10"])
    %Runner{ state: %{...object => %{parsed_state => %{foo: 2} } } }
    iex> Command.random(%Runner{}, ["foo", "one", "two", "three"])
    %Runner{ state: %{...object => %{parsed_state => %{foo: "three"} } }
  """
  def random(%Runner{} = runner_state, [state_variable | values]) do
    random_value = if length(values) == 1 and Regex.match?(~r/^\d+\s?-\s?\d+$/, Enum.at(values,0)) do
                      [lower, upper] = String.split( Enum.at(values, 0), ~r/\s*-\s*/)
                                       |> Enum.map(&String.to_integer/1)
                      Enum.random(lower..upper)
                    else
                      Enum.random(values)
                    end
    change_state(runner_state, [String.to_atom(state_variable), "=", random_value])
  end

  @doc """
  Replaces a map tile. Uses KWARGs, `target` and attributes prefixed with `target_` can be used to specify which tiles to replace.
  `target` can be the name of a tile, or a direction. The other `target_` attributes must also match along with the `target`.
  At least one attribute or slug KWARG should be used to specify what to replace the targeted tile with. If there are many tiles with
  that name, then all those tiles will be replaced. For a direction, only the top tile will be removed when there are more
  than one tiles there.
  If there are no tiles matching, nothing is done. Player tiles will not be replaced.
  """
  def replace(%Runner{} = runner_state, [params]) do
    [target_conditions, new_params] = params
                                      |> Enum.map(fn {k, v} -> {Atom.to_string(k), resolve_variable(runner_state, v)} end)
                                      |> Enum.split_with( fn {k,_} -> Regex.match?( ~r/^target/, k ) end )
                                      |> Tuple.to_list
                                      |> Enum.map(fn partition ->
                                           Enum.map(partition, fn {k, v} -> {String.to_atom(String.replace_leading(k, "target_", "")), v} end)
                                           |> Enum.into(%{})
                                         end)
    _replace(runner_state, target_conditions, new_params)
  end

  defp _replace(%Runner{state: state} = runner_state, target_conditions, new_params) do
    {target, target_conditions} = Map.pop(target_conditions, :target)
    target = if target, do: String.downcase(target), else: nil

    if Direction.valid_orthogonal?(target) do
      _replace_in_direction(runner_state, target, target_conditions, new_params)
    else
      map_tile_ids = state.map_by_ids
                     |> Map.to_list
                     |> _filter_tiles_with(target, target_conditions)
                     |> Enum.map(fn {id, _tile} -> id end)
      _replace_via_ids(runner_state, map_tile_ids, new_params)
    end
  end

  defp _replace_in_direction(%Runner{state: state, object_id: object_id} = runner_state, direction, target_conditions, new_params) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    map_tile = Instances.get_map_tile(state, object, direction)

    if map_tile && Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _map_tile_value(map_tile, key) == val end) do
      _replace_via_ids(runner_state, [map_tile.id], new_params)
    else
      runner_state
    end
  end

  defp _replace_via_ids(runner_state, [], _new_params), do: runner_state
  defp _replace_via_ids(%Runner{state: state, program: program} = runner_state, [id | ids], new_params) do
    if Instances.is_player_tile?(state, %{id: id}) do
      _replace_via_ids(runner_state, ids, new_params)
    else
      %Runner{program: other_program, state: state} = become(%{runner_state | object_id: id}, [new_params])
      _replace_via_ids(%{runner_state | state: state, program: %{ program | broadcasts: other_program.broadcasts}}, ids, new_params)
    end
  end

  defp _map_tile_value(map_tile, key) do
    if Map.has_key?(map_tile, key) do
      Map.get(map_tile, key)
    else
      map_tile.parsed_state[key]
    end
  end

  defp _filter_tiles_with(_tile_map, nil, %{} = target_conditions) when map_size(target_conditions) == 0, do: []

  defp _filter_tiles_with(tile_map, nil, target_conditions) do
    tile_map
    |> Enum.filter(fn {_id, tile} ->
         Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _map_tile_value(tile, key) == val end)
       end)
  end

  defp _filter_tiles_with(tile_map, target, target_conditions) do
    tile_map
    |> Enum.filter(fn {_id, tile} ->
         String.downcase(tile.name || "") == target &&
           Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _map_tile_value(tile, key) == val end)
       end)
  end

  @doc """
  Removes a map tile. Uses kwargs, the `target` KWARG in addition to other attribute targets may be used.
  Valid targets are a direction, or the name (case insensitive) of a tile. If there are many tiles with
  that name, then all those tiles will be removed. For a direction, only the top tile will be removed when there are more
  than one tiles there. If there are no tiles matching, nothing is done.
  Player tiles will not be removed.
  """
  def remove(%Runner{} = runner_state, [params]) do
    target_conditions = params
                        |> Enum.map(fn {k, v} ->
                             { Atom.to_string(k) |> String.replace_leading( "target_", "") |> String.to_atom(),
                               resolve_variable(runner_state, v) }
                           end)
                        |> Enum.into(%{})

    _remove(runner_state, target_conditions)
  end

  def _remove(%Runner{state: state} = runner_state, target_conditions) do
    {target, target_conditions} = Map.pop(target_conditions, :target)
    target = if target, do: String.downcase(target), else: nil

    if Direction.valid_orthogonal?(target) do
      _remove_in_direction(runner_state, target, target_conditions)
    else
      map_tile_ids = state.map_by_ids
                     |> Map.to_list
                     |> _filter_tiles_with(target, target_conditions)
                     |> Enum.map(fn {id, _tile} -> id end)
      _remove_via_ids(runner_state, map_tile_ids)
    end
  end

  defp _remove_in_direction(%Runner{state: state, object_id: object_id} = runner_state, direction, target_conditions) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    map_tile = Instances.get_map_tile(state, object, direction)

    if map_tile && Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _map_tile_value(map_tile, key) == val end) do
      _remove_via_ids(runner_state, [map_tile.id])
    else
      runner_state
    end
  end

  defp _remove_via_ids(runner_state, []), do: runner_state
  defp _remove_via_ids(%Runner{state: state} = runner_state, [id | ids]) do
    if Instances.is_player_tile?(state, %{id: id}) do
      _remove_via_ids(runner_state, ids)
    else
      {_deleted_object, updated_state} = Instances.delete_map_tile(state, %{id: id})

      _remove_via_ids(
        %{ runner_state | state: updated_state },
        ids
      )
    end
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
  `here` - all tiles with the same row/col as the sending object, including the object.
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
  defp _send_message(%Runner{} = runner_state, [label, target]) when is_integer(target) do
    _send_message_via_ids(runner_state, label, [target])
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
  defp _send_message(%Runner{} = runner_state, [label, target]) when target == "here" do
    _send_message_in_direction(runner_state, label, target)
  end
  defp _send_message(%Runner{} = runner_state, [label, target]) when is_valid_orthogonal(target) do
    _send_message_in_direction(runner_state, label, target)
  end
  defp _send_message(%Runner{state: state} = runner_state, [label, target]) do
    map_tile_ids = state.map_by_ids
                   |> Map.to_list
                   |> Enum.filter(fn {_id, tile} -> String.downcase(tile.name || "") == target end)
                   |> Enum.map(fn {id, _tile} -> id end)
    _send_message_via_ids(runner_state, label, map_tile_ids)
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
      %{ runner_state | state: %{ state | program_messages: [ {po_id, label, %{map_tile_id: object_id, parsed_state: object.parsed_state, name: object.name}} |
                                                              state.program_messages] } },
      label,
      program_object_ids
    )
  end

  @doc """
  Sets the specified state variable to the next value in the given sequence. The first parameter is the
  state variable, and the subsequent parameters are the sequence values. As a side effect this will
  update the instruction and move the HEAD element of the sequence to the tail.

  ## Examples

    iex> Command.sequence(%Runner{}, ["foo", "red", "yellow", "blue"])
    %Runner{ state: %{...object => %{parsed_state => %{foo: "red"} } },
             program: %{instructions: %{program.pc => [:sequence, ["foo", ["yellow", "blue", "red"]] ] } }
  """
  def sequence(%Runner{} = runner_state, [state_variable | [head | tail]]) do
    runner_state = change_state(runner_state, [String.to_atom(state_variable), "=", head])

    updated_instruction = [:sequence, [state_variable | Enum.reverse([ head | Enum.reverse(tail)])] ]
    instructions = %{ runner_state.program.instructions | runner_state.program.pc => updated_instruction }

    %{ runner_state | program: %{ runner_state.program | instructions: instructions } }
  end

  @doc """
  Rotates all the `pushable` tiles in the 8 adjacent squares about the object.
  Valid parameters are `clockwise` or `counterclockwise` to rotate in those respective
  directions.
  """
  def shift(%Runner{state: state, object_id: object_id, program: program} = runner_state, [direction]) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})

    shiftables = _shift_coords(direction, _shift_adj_coords())
                 |> Enum.map(fn({{row_d, col_d}, {dest_row_d, dest_col_d}}) ->
                      { Instances.get_map_tile(state, %{row: object.row + row_d, col: object.col + col_d}),
                        Instances.get_map_tile(state, %{row: object.row + dest_row_d, col: object.col + dest_col_d}) }
                    end)
                 |> Enum.filter(fn({tile, _dest_tile}) -> tile && tile.parsed_state[:pushable] end)
                 |> Enum.reject(fn({_tile, dest_tile}) -> !dest_tile || dest_tile.parsed_state[:blocking] && !dest_tile.parsed_state[:pushable] end)

    {runner_state, _, tile_changes} = _shifting(runner_state, shiftables, %{})

    # TODO: see if Move.go needs the {row, col} return anymore, or if it can be swapped with %{row: _, col: _}
    rerender_coords = tile_changes
                      |> Map.to_list
                      |> Enum.map(fn { {row, col}, _tile } -> %{row: row, col: col} end)
                      |> Enum.reduce(state.rerender_coords, fn coords, rerender_coords -> Map.put(rerender_coords, coords, true) end)

    %Runner{ runner_state |
             state: %{ runner_state.state | rerender_coords: rerender_coords },
             program: %{program |
                        status: :wait,
                        wait_cycles: object.parsed_state[:wait_cycles] || 5 } }
  end

  defp _shifting(%Runner{} = runner_state, [], tile_changes), do: {runner_state, [], tile_changes}
  defp _shifting(%Runner{} = runner_state, shiftables, tile_changes) do
    {runner_state, shifts_pending, tile_changes} = _shifting(runner_state, shiftables, [], tile_changes)

    if length(shifts_pending) == length(shiftables) do
      {runner_state, [], tile_changes}
    else
      refreshed_shifts_pending = Enum.reverse(shifts_pending)
                               |> Enum.map(fn({tile, dest_tile}) -> {tile, Instances.get_map_tile(runner_state.state, dest_tile)} end)

      _shifting(runner_state, refreshed_shifts_pending, tile_changes)
    end
  end

  defp _shifting(%Runner{} = runner_state, [], shifts_pending, tile_changes), do: {runner_state, shifts_pending, tile_changes}
  defp _shifting(%Runner{state: state} = runner_state, [{tile, dest_tile} | other_pairs], shifts_pending, tile_changes) do
    if dest_tile.parsed_state[:blocking] do
      _shifting(runner_state, other_pairs, [ {tile, dest_tile} | shifts_pending], tile_changes)
    else
      {_, tile_changes, state} = Move.go(tile, dest_tile, state, :absolute, tile_changes)
      _shifting(%{runner_state | state: state}, other_pairs, shifts_pending, tile_changes)
    end
  end

  defp _shift_adj_coords() do
    [{-1, -1},
     {-1,  0},
     {-1,  1},
     { 0,  1},
     { 1,  1},
     { 1,  0},
     { 1, -1},
     { 0, -1}]
  end

  defp _shift_coords("clockwise", [ head | tail ] = adj) do
    shifted = Enum.reverse([ head | Enum.reverse(tail)])
    Enum.zip(adj, shifted)
  end

  defp _shift_coords("counterclockwise", adj) do
    [last | front_tail] = Enum.reverse(adj)
    shifted = [ last | Enum.reverse(front_tail) ]
    Enum.zip(adj, shifted)
  end

  @doc """
  Fires a bullet in the given direction. The bullet will spawn on the same tile as the object.
  The bullet will walk in given direction until it hits something, or something
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
  def take(%Runner{} = runner_state, [what, amount, from_whom]) do
    _take(runner_state, what, amount, from_whom, nil)
  end
  def take(%Runner{} = runner_state, [what, amount, from_whom, label]) do
    _take(runner_state, what, amount, from_whom, label)
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
    with direction <- resolve_variable(runner_state, direction),
         direction when is_valid_orthogonal(direction) <- direction,
         object when not is_nil(object) <- Instances.get_map_tile_by_id(state, %{id: object_id}),
         map_tile when not is_nil(map_tile) <- Instances.get_map_tile(state, object, direction) do
      _take(runner_state, what, amount, map_tile.id, label)
    else
      _ ->
        runner_state
    end
  end

  defp _take_via_id(%Runner{state: state, program: program} = runner_state, what, amount, id, label) do
    amount = resolve_variable(runner_state, amount)
    what = resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      what = String.to_atom(what)

      case Instances.subtract(state, what, amount, id) do
        {:ok, state} ->
          %{ runner_state | state: state }

        {:not_enough, _state} ->
          if label do
            updated_program = %{ runner_state.program | pc: Program.line_for(program, label), status: :wait, wait_cycles: 1 }
            %{ runner_state | program: updated_program }
          else
            runner_state
          end

        {_noop_or_no_loser, _state} ->
          runner_state
      end
    else
      runner_state
    end
  end

  @doc """
  Targets a player. If there is already a target player (target_player_map_tile_id), it will be replaced
  by this command. Two different parameters may be used; nearest and random. Nearest will target the closest player
  (if more than one are the same distance, one is chosen at random). Random picks a random player as the target.
  When no suitable targets are to be found, @target_player_map_tile_id is set to nil
  """
  def target_player(%Runner{state: %{player_locations: locs}} = runner_state, _) when locs == %{} do
    change_state(runner_state, [:target_player_map_tile_id, "=", nil])
  end

  def target_player(%Runner{} = runner_state, [what]) do
    _target_player(runner_state, String.downcase(what))
  end

  defp _target_player(%Runner{object_id: object_id, state: state} = runner_state, "nearest") do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    player_map_tile = \
    Map.keys(state.player_locations)
    |> Enum.map(fn(map_tile_id) ->
         map_tile = Instances.get_map_tile_by_id(state, %{id: map_tile_id})
         {Direction.distance(map_tile, object), map_tile}
       end)
    |> Enum.reduce([1000, []], fn {distance, map_tile}, [closest, map_tiles] ->
         cond do
           distance < closest ->
             [distance, [ map_tile ] ]

           distance == closest ->
             [closest, [ map_tile | map_tiles ]]

           true ->
             [closest, map_tiles]
         end
       end)
    |> Enum.at(1)
    |> Enum.random()

    change_state(runner_state, [:target_player_map_tile_id, "=", player_map_tile.id])
  end

  defp _target_player(%Runner{state: state} = runner_state, "random") do
    map_tile_ids = Map.keys(state.player_locations)
    player_map_tile_id = Enum.random(map_tile_ids)
    change_state(runner_state, [:target_player_map_tile_id, "=", player_map_tile_id])
  end

  defp _target_player(%Runner{} = runner_state, _), do: runner_state

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
  When there are multiple text commands adjacent, then they will be combined and displayed together
  in a modal.

  Additionally, this will advance the program's pc to the last text instruction that was included
  in the response.

  When a label is provided as the second parameter, then the text will be able to be clicked by
  the player.

  When the initial text is empty string `""`, nothing is done. However empty strings or new lines
  will be included after the first non empty text

  ## Examples

    iex> Command.text(%Runner{program: program}, params: ["Door opened"])
    %Runner{ program: %{program | responses: ["Door opened"]} }
  """
  def text(%Runner{event_sender: event_sender} = runner_state, params) do
    if params != [""] do
      { %Runner{program: program, state: state} = runner_state, lines, labels } = _process_text(runner_state, runner_state.program.pc)

      payload = if length(lines) == 1 && ! String.contains?(Enum.at(lines, 0), "messageLink") do
                  %{message: Enum.at(lines, 0)}
                else
                  %{message: Enum.reverse(lines), modal: true}
                end

      program = %{ program |  responses: [ {"message", payload} | program.responses] }

      case event_sender do
        # only care about tracking available actions sent to a player
        %Location{map_tile_instance_id: id} ->
          state = Instances.set_message_actions(state, id, labels)
          %{ runner_state | program: program, state: state }

        _ ->
          %{ runner_state | program: program }
      end
    else
      runner_state
    end
  end

  defp _process_text(%Runner{program: program, object_id: object_id} = runner_state, pc, lines \\ [], labels \\ []) do
    case program.instructions[pc] do
      [:text, [another_line]] ->
        runner_state = %{runner_state | program: %{ program | pc: pc }}
        {:safe, safe_text} = html_escape(another_line)
        _process_text(runner_state, pc + 1, [ "#{ safe_text }" | lines], labels)

      [:text, [another_line, label]] ->
        runner_state = %{runner_state | program: %{ program | pc: pc }}
        {:safe, safe_text} = html_escape(another_line)
        attrs = "class='btn-link messageLink' data-label='#{ label }' data-tile-id='#{ object_id }'"
        _process_text(runner_state, pc + 1, [ "    <span #{attrs}>▶#{ safe_text }</span>" | lines], [ String.downcase(label) | labels ])

      _ ->
        {runner_state, lines, labels}
    end
  end

  @doc """
  Transports a player map tile from one dungeon instance to another dungeon instance that is part
  of the same map set. First param is the who (which should resolve to a map tile id; but if its not
  a player's map tile this command will do nothing).

  Second param can either be a fixed level number, "up" or "down" (up or down will resolve to the level
  above or below the current one). If the level doesn't exist the nothing will be done.

  Third param is optional, and is used to specify what passage_exit will be used.
  For example, if the match key is "green", then only passage exits that also have that match key will be considered.
  When more than one match, one is randomly picked. Also, when there is no match key specified, a random passage_exit
  will be used. When no match key is specified, and there are no passage exits, then a random spawn coordinate will
  be used as a last option.

  ## Examples

    iex> Command.transport(%Runner{program: %Program{},
                                   object_id: object_id,
                                   state: state},
                     [[:event_sender], "up", "stairsdown"])
    %Runner{}
  """
  def transport(runner_state, params, travel_module \\ Travel)
  def transport(%Runner{} = runner_state, [who, level], travel_module) do
    transport(runner_state, [who, level, nil], travel_module)
  end
  def transport(%Runner{event_sender: event_sender} = runner_state, [[:event_sender], level, match_key], travel_module) do
    case event_sender do
      %{map_tile_instance_id: id} -> transport(runner_state, [id, level, match_key], travel_module) # player tile
      _                           -> runner_state
    end
  end

  def transport(%Runner{state: state} = runner_state, [who, level, match_key], travel_module) do
    map_tile_id = case resolve_variable(runner_state, who) do
                    %{id: id} -> id
                    id        -> id
                  end
    level = resolve_variable(runner_state, level)
    match_key = resolve_variable(runner_state, match_key)
    player_location = Instances.get_player_location(state, %{id: map_tile_id})
    _transport(runner_state, player_location, level, match_key, travel_module)
  end

  defp _transport(runner_state, nil, _level, _match_key, _travel_module) do
    runner_state
  end

  defp _transport(%Runner{state: state} = runner_state, player_location, "up", match_key, travel_module) do
    _transport(runner_state, player_location, state.number + 1, match_key, travel_module)
  end

  defp _transport(%Runner{state: state} = runner_state, player_location, "down", match_key, travel_module) do
    _transport(runner_state, player_location, state.number - 1, match_key, travel_module)
  end

  defp _transport(%Runner{state: state, object_id: object_id} = runner_state, player_location, level_number, match_key, travel_module) do
    passage = Map.put(Instances.get_map_tile_by_id(state, %{id: object_id}) || %{}, :match_key, match_key)
    {:ok, state} = travel_module.passage(player_location, passage, level_number, state)
    %{ runner_state | state: state }
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
  Unlocks the object. This will allow it to receive and act on any
  message/event it may receive. The underlying state value `locked`
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
    next_actions = %{pc: program.pc - 1, lc: 0, invalid_move_handler: &_invalid_simple_command/3}
    _move(runner_state, direction, false, next_actions, &Move.go/3)
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
