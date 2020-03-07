defmodule DungeonCrawl.Scripting.Command do
  @moduledoc """
  The various scripting commands available to a program.
  """

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Maths
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileState
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
      :die          -> :die
      :end          -> :halt
      :facing       -> :facing
      :go           -> :go
      :if           -> :jump_if
      :move         -> :move
      :noop         -> :noop
      :text         -> :text
      :try          -> :try
      :walk         -> :walk

      _ -> nil
    end
  end

  @doc """
  Transforms the given object in some way. Changes can include character, color, background color, state, script
  and tile_template_id. Just changing the tile_template_id does not copy all other attributes of that tile template
  to the object. The object will likely be a map_tile instance.

  Changes will be persisted to the database, and a message added to the broadcasts list for the tile_changes that
  occurred. The updated object will be returned in the return map.

  ## Examples

    iex> Command.become(%Runner{}, [%{character: $}])
    %Runner{program: %{program | broadcasts: [ ["tile_changes", %{tiles: [%{row: 1, col: 1, rendering: "<div>$</div>"}]}] ]},
      object: updated_object,
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
  def _become(%Runner{program: program, object: object, state: state}, new_attrs) do
    {object, state} = Instances.update_map_tile( 
                      state,
                      object,
                      new_attrs)

    message = ["tile_changes",
               %{tiles: [
                   Map.put(Map.take(object, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(object))
               ]}]

    if Map.has_key?(new_attrs, :script) do
      {:ok, new_program} = Scripting.Parser.parse(new_attrs.script)
      state = %{ state | program_contexts: Map.put(state.program_contexts, object.id, new_program) }
      %Runner{ program: %{new_program | broadcasts: [message | program.broadcasts], responses: program.responses, status: :idle },
               object: object,
               state: state}
    else
      %Runner{ program: %{program | broadcasts: [message | program.broadcasts] },
               object: object,
               state: state }
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

  ## Examples

    iex> Command.change_state(%Runner{program: program, object: %{state: "counter: 1"}, state: state}, [:counter, "+=", 3])
    %Runner{program: program,
      object: %{ object | state: "counter: 4"},
      state: updated_state }
  """
  def change_state(%Runner{object: object, state: state} = runner_state, params) do
    {:ok, object_state} = TileState.Parser.parse(object.state)
    [var, op, value] = params

    object_state = Map.put(object_state, var, Maths.calc(object_state[var] || 0, op, value))
    object_state_str = TileState.Parser.stringify(object_state)
    {updated_object, updated_state} = Instances.update_map_tile(state, object, %{state: object_state_str, parsed_state: object_state})

    %Runner{ runner_state | object: updated_object, state: updated_state }
  end

  @doc """
  Similar to MOVE. This method is not directly accessable in the script as a normal command.
  Rather, a line of short hand movement commands will be parsed and run via `compound_move`.
  A short hand movement is two characters. A backslash or a question mark followed by a
  direction character (n, s, e, w, or i, case insensitive).

  A backslash will retry that movement until successful (unless the program also responds to
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

  \n\n\n - move north three times
  \e?n?n - move east once, then try to move north twice

  For purposes of keeping track of which of the shorthand movements the command is on, the `lc` - line counter
  element on the program is used.

  The parameters expected are an enumerable containing tuples of 2. The first element of the tuple, and the second
  is if the movement should retry until successful. The behavior is similar to the regular move command.

  ## Examples

    iex> Command.compound_move(%Runner{program: %Program{}, object: object, state: state}, [{"north", true}, {"east", false}])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
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
  Kills the script for the object. Returns a dead program, and deletes the script from the object (map_tile instance)

  ## Examples

    iex> Command.die(%Runner{program: program, object: %{script: "..."}, state: state}
    %Runner{program: %{program | pc: -1, status: :dead},
      object: %{ object | script: ""},
      state: updated_state }
  """
  def die(%Runner{program: program, object: object, state: state}, _ignored \\ nil) do
    {updated_object, updated_state} = Instances.update_map_tile(state, object, %{script: ""})
    %Runner{program: %{program | status: :dead, pc: -1},
            object: updated_object,
            state: updated_state}
  end

  @doc """
  Move in the given direction, and keep retrying until successful.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.go(%Runner{program: %Program{}, object: object, state: state}, ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
  """
  def go(runner_state, [direction]) do
    move(runner_state, [direction, true])
  end

  @doc """
  Changes the program state to idle and sets the pc to -1. This indicates that the program is still alive,
  but awaiting a message to respond to (ie, a TOUCH event)
  END is what would be put in the script.

  ## Examples

    iex> Command.halt(%Runner{program: program, object: object, state: state})
    %Runner{program: %{program | pc: -1, status: :idle},
      object: object,
      state: state }
  """
  def halt(%Runner{program: program} = runner_state, _ignored \\ nil) do
    %Runner{ runner_state | program: %{program | status: :idle, pc: -1} }
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
    facing(new_runner_state, [player_direction])
  end
  def facing(%Runner{object: object} = runner_state, ["clockwise"]) do
    {:ok, object_state} = TileState.Parser.parse(object.state)
    direction = case object_state.facing do
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
    change_state(runner_state, [:facing, "=", direction])
  end
  def facing(%Runner{object: object} = runner_state, ["counterclockwise"]) do
    {:ok, object_state} = TileState.Parser.parse(object.state)
    direction = case object_state.facing do
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
    change_state(runner_state, [:facing, "=", direction])
  end
  def facing(%Runner{object: object} = runner_state, ["reverse"]) do
    {:ok, object_state} = TileState.Parser.parse(object.state)
    direction = case object_state.facing do
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
    change_state(runner_state, [:facing, "=", direction])
  end
  def facing(runner_state, [direction]) do
    change_state(runner_state, [:facing, "=", direction])
  end

  @doc """
  Conditionally jump to a label. Program counter (pc) will be set to the location of the first active label
  if the expression evaluates to true. Otherwise the pc will not be changed. If there is no active matching label,
  the pc will also be unchanged.
  """
  def jump_if(%Runner{program: program, object: object} = runner_state, params) do
    {:ok, object_state} = DungeonCrawl.TileState.Parser.parse(object.state)
    [[neg, _command, var, op, value], label] = params

    # first active matching label
    with line_number when not is_nil(line_number) <- Program.line_for(program, label),
         true <- Maths.check(neg, object_state[var], op, value) do
      %Runner{ runner_state | program: %{program | pc: line_number, lc: 0} }
    else
      _ -> runner_state
    end
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

    iex> Command.move(%Runner{program: %Program{}, object: object, state: state}, ["n", true])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
  """
  def move(%Runner{program: program} = runner_state, ["idle", _]) do
    %Runner{ runner_state | program: %{program | status: :wait, wait_cycles: 5 } }
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
  defp _move(%Runner{program: program} = runner_state, "idle", _retryable, next_actions) do
    %Runner{ runner_state | program: %{program | pc: next_actions.pc,
                                                 lc: next_actions.lc,
                                                 status: :wait,
                                                 wait_cycles: 5 }}
  end
  defp _move(%Runner{program: program, object: object, state: state} = runner_state, direction, retryable, next_actions) do
    direction = _get_real_direction(object, direction)

    destination = Instances.get_map_tile(state, object, direction)

    case Move.go(object, destination, state) do
      {:ok, %{new_location: new_location, old_location: old}, new_state} ->

        message = ["tile_changes",
               %{tiles: [
                     Map.put(Map.take(new_location, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(new_location)),
                     Map.put(Map.take(old, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(old))
               ]}]

        updated_runner_state = %Runner{ program: %{program | pc: next_actions.pc,
                                                             lc: next_actions.lc,
                                                             broadcasts: [message | program.broadcasts],
                                                             status: :wait,
                                                             wait_cycles: 5 },
                                        object: new_location,
                                        state: new_state}
        if direction != "idle" do
          change_state(updated_runner_state, [:facing, "=", direction])
        else
          updated_runner_state
        end

      {:invalid} ->
        next_actions.invalid_move_handler.(runner_state, retryable)
    end
  end

  defp _get_real_direction(object, "continue") do
    {:ok, object_state} = TileState.Parser.parse(object.state)
    object_state.facing || "idle"
  end
  defp _get_real_direction(_object, direction), do: direction

  defp _invalid_compound_command(%Runner{program: program} = runner_state, retryable) do
    cond do
      line_number = Program.line_for(program, "THUD") ->
          %Runner{ runner_state | program: %{program | pc: line_number, lc: 0} }
      retryable ->
          %Runner{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: 5} }
      true ->
          %Runner{ runner_state | program: %{program | pc: program.pc - 1, lc: program.lc + 1,  status: :wait, wait_cycles: 5} }
    end
  end

  defp _invalid_simple_command(%Runner{program: program} = runner_state, retryable) do
    cond do
      line_number = Program.line_for(program, "THUD") ->
          %Runner{ runner_state | program: %{program | pc: line_number} }
      retryable ->
          %Runner{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: 5} }
      true ->
          %Runner{ runner_state | program: %{program | status: :wait, wait_cycles: 5} }
    end
  end

  @doc """
  Non operation. Returns unaltered parameters.

  ## Examples

    iex> Command.noop(%Runner{program: %Program{}, object: object})
    %Runner{program: %Program{}, object: object}
  """
  def noop(%Runner{} = runner_state, _ignored \\ nil) do
    runner_state
  end

  @doc """
  Adds text to the responses for showing to a player in particular (ie, one who TOUCHed the object).

  ## Examples

    iex> Command.text(%Runner{program: program, object: object, params: ["Door opened"], state: state})
    %Runner{program: %{program | responses: ["Door opened"]},
      object: object,
      state: state }
  """
  def text(%Runner{program: program} = runner_state, params) do
    if params != [""] do
      # TODO: probably allow this to be refined by whomever the message is for
      message = Enum.map(params, fn(param) -> String.trim(param) end) |> Enum.join("\n")
      %Runner{ runner_state | program: %{program | responses: [ message | program.responses] } }
    else
      runner_state
    end
  end

  @doc """
  Attempt to move in the given direction, if blocked the object doesn't move but the `THUD` message
  will still be sent.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.try(%Runner{program: %Program{}, object: object, state: state}, ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
  """
  def try(runner_state, [direction]) do
    move(runner_state, [direction, false])
  end

  @doc """
  Continue to move in the given direction until bumping into something. Similar to `TRY` but repeats until
  it cannot move in the given direction anymore.

  See the `move` command for valid directions.

  ## Examples

    iex> Command.try(%Runner{program: %Program{}, object: object, state: state}, ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
  """
  def walk(%Runner{program: program} = runner_state, [direction]) do
    next_actions = %{pc: program.pc - 1, lc: 0, invalid_move_handler: &_invalid_simple_command/2}
    _move(runner_state, direction, false, next_actions)
  end

  defp _direction_of_player(%Runner{object: object} = runner_state) do
    target_player_map_tile_id = object.parsed_state[:target_player_map_tile_id]
    _direction_of_player(runner_state, target_player_map_tile_id)
  end
  defp _direction_of_player(%Runner{state: state} = runner_state, nil) do
    with map_tile_ids when length(map_tile_ids) != 0 <- Map.keys(state.player_locations),
         player_map_tile_id <- Enum.random(map_tile_ids) do

      _direction_of_player(change_state(runner_state, [:target_player_map_tile_id, "=", player_map_tile_id]))
    else
      _ -> {runner_state, "idle"}
    end
  end
  defp _direction_of_player(%Runner{state: state, object: object} = runner_state, target_player_map_tile_id) do
    with player_map_tile when player_map_tile != nil <- Instances.get_map_tile_by_id(state, %{id: target_player_map_tile_id}) do
      {runner_state, Instances.direction_of_map_tile(state, object, player_map_tile)}
    else
      _ ->
      _direction_of_player(change_state(runner_state, [:target_player_map_tile_id, "=", nil]))
    end
  end
end
