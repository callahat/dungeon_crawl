defmodule DungeonCrawl.Scripting.Command do
  @moduledoc """
  The various scripting commands available to a program.
  """

  alias DungeonCrawl.Action.{Move, Pull, Shoot, Travel}
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.{Levels, LevelProcess, LevelRegistry,
                                       DungeonRegistry, DungeonProcess, Registrar}
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Equipment.Item
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Maths
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Shape
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Sound.Effect
  alias DungeonCrawl.StateValue
  alias DungeonCrawl.TileTemplates

  import DungeonCrawl.Scripting.VariableResolution, only: [resolve_variables: 2, resolve_variable: 2]
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
  def get_command(name) when is_atom(name), do: get_command(Atom.to_string(name))
  def get_command(name) do
    case name |> String.downcase() |> String.trim() do
      "become"       -> :become
      "change_state" -> :change_state
      "change_instance_state" -> :change_level_instance_state # deprecated
      "change_level_instance_state" -> :change_level_instance_state
      "change_map_set_instance_state" -> :change_dungeon_instance_state # deprecated
      "change_dungeon_instance_state" -> :change_dungeon_instance_state
      "change_other_state" -> :change_other_state
      "cycle"        -> :cycle
      "die"          -> :die
      "end"          -> :halt
      "equip"        -> :equip
      "facing"       -> :facing
      "gameover"     -> :gameover
      "give"         -> :give
      "go"           -> :go
      "if"           -> :jump_if
      "lock"         -> :lock
      "move"         -> :move
      "noop"         -> :noop
      "passage"      -> :passage
      "pull"         -> :pull
      "push"         -> :push
      "put"          -> :put
      "random"       -> :random
      "replace"      -> :replace
      "remove"       -> :remove
      "restore"      -> :restore
      "send"         -> :send_message
      "sequence"     -> :sequence
      "shift"        -> :shift
      "shoot"        -> :shoot
      "sound"        -> :sound
      "take"         -> :take
      "target_player" -> :target_player
      "terminate"    -> :terminate
      "text"         -> :text
      "transport"    -> :transport
      "try"          -> :try
      "unequip"      -> :unequip
      "unlock"       -> :unlock
      "walk"         -> :walk
      "zap"          -> :zap

      _ -> nil
    end
  end

  @doc """
  Transforms the object refernced by the id in some way. Changes can include character, color, background color.
  Additionally, if given a `slug`, the tile will be replaced with the matching tile template corresponding to the
  given slug. Other changes given, such as name, character, color, background color, will override the values from
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
  def become(%Runner{} = runner_state, [%{} = params]) do
    {slug_tile, runner_state} = _get_tile_template(runner_state, params["slug"])

    new_attrs = _tile_template_copy_fields(slug_tile)
                |> Map.merge(Map.take(params, ["name", "character", "color", "background_color"]))

    new_state_attrs = Map.take(params, Map.keys(params) -- _tile_template_keys())

    _become(runner_state, new_attrs, new_state_attrs)
  end
  def become(runner_state, _), do: runner_state
  def _become(runner_state, new_attrs, new_state_attrs) when new_attrs == %{} and new_state_attrs == %{}, do: runner_state
  def _become(%Runner{program: program, object_id: object_id, state: state} = runner_state, new_attrs, new_state_attrs) do
    new_attrs = resolve_variables(runner_state, new_attrs)
    new_state_attrs = resolve_variables(runner_state, new_state_attrs)

    object = Levels.get_tile_by_id(state, %{id: object_id})

    case Tile.changeset(object, new_attrs).valid? do
      true -> # all that other stuff below
        {object, state} = Levels.update_tile(
                          state,
                          %{id: object_id},
                          new_attrs)
        {object, state} = Levels.update_tile_state(
                          state,
                          object,
                          new_state_attrs)

        current_program = cond do
                            is_nil(Map.get(state.program_contexts, object.id)) ->
                              %{ program | status: :dead }
                            Map.has_key?(new_attrs, "script") ->
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

  defp _get_tile_template(%{ state: state } = runner_state, slug) do
    case Levels.get_tile_template(slug, state) do
      {tile_template, state, :created} -> {tile_template, %{ runner_state | state: state }}
      {tile_template, _state, _} -> {tile_template, runner_state}
    end
  end

  defp _tile_template_copy_fields(slug_tile) do
    TileTemplates.copy_fields(slug_tile)
    |> Enum.map(fn {k,v} when is_atom(k) -> {Atom.to_string(k), v}
                   pair -> pair
                end)
    |> Enum.into(%{})
  end

  defp _tile_template_keys() do
    Map.keys(%TileTemplates.TileTemplate{})
    |> Enum.map(&Atom.to_string/1)
  end

  @doc """
  Changes the object's state element given in params. The params also specify what operation is being used,
  and the value to use in conjunction with the value from the state. When there is no state value;
  0 is used as default. The params list is ordered:

  [<name of the state value>, <operator>, <right side value>]

  See the Maths module calc function definitions for valid operators.

  When it is a binary operator (ie, "=", "+=" etc) the right side value is used to change the object's
  state value by adding it, subtracting it, setting it, etc with the right side value.

  Change is persisted to the DB for the object (tile instance)

  Case sensitive

  ## Examples

    iex> Command.change_state(%Runner{program: program,
                                      object_id: 1,
                                      state: %Levels{map_by_ids: %{1 => %{state: %{"counter" => 1}},...}, ...}},
                              ["counter", "+=", 3])
    %Runner{program: program,
            state: %Levels{map_by_ids: %{1 => %{state: %{"counter" => 4}},...}, ...} }
  """
  def change_state(%Runner{object_id: object_id} = runner_state, [var, op, value]) do
    value = resolve_variable(runner_state, value)
    _change_state(runner_state, object_id, var, op, value)
  end

  @doc """
  Changes the instance state_values element given in params. (Similar to change_state)

  ## Examples

    iex> Command.change_level_instance_state(%Runner{program: program,
                                               state: %Levels{state_values: %{}}},
                                       ["counter", "+=", 3])
    %Runner{program: program,
            state: %Levels{map_by_ids: %{1 => %{state: %{"counter" => 4}},...}, ...} }
  """
  def change_level_instance_state(%Runner{state: state} = runner_state, [var, _op, _value] = params)
      when var in ["visibility", "fog_range"] do
    runner_state = %{ runner_state | state: %{ state | full_rerender: true, players_visible_coords: %{} } }
    _change_level_instance_state(runner_state, params)
  end
  def change_level_instance_state(%Runner{} = runner_state, params) do
    _change_level_instance_state(runner_state, params)
  end
  def _change_level_instance_state(%Runner{state: state} = runner_state, [var, op, value]) do
    value = resolve_variable(runner_state, value)

    state_values = Map.put(state.state_values, var, Maths.calc(state.state_values[var] || 0, op, value))

    %Runner{ runner_state | state: %{ state | state_values: state_values } }
  end

  @doc """
  Changes the dungeon instance state_values element given in params. (Similar to change_state)

  ## Examples

    iex> Command.change_dungeon_instance_state(%Runner{program: program,
                                                       state: %Levels{state_values: %{}}},
                                               ["counter", "+=", 3])
    %Runner{program: program,
            state: %Levels{map_by_ids: %{1 => %{state: %{"counter" => 4}},...}, ...} }
  """
  def change_dungeon_instance_state(%Runner{state: state} = runner_state, params) do
    [var, op, value] = params
    value = resolve_variable(runner_state, value)

    {:ok, dungeon_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id)
    old_val = DungeonProcess.get_state_value(dungeon_process, var)
    new_val = Maths.calc(old_val || 0, op, value)
    DungeonProcess.set_state_value(dungeon_process, var, new_val)

    runner_state
  end

  @doc """
  Changes the state_value for an object given in the params. The target object can be specified by
  a direction (relative from the current object) or by a tile id. Not valid against player tiles.

  ## Examples

    iex> Command.change_other_state(%Runner{program: program,
                                               state: %Levels{state_values: %{}}},
                                       ["north", :space, "=", 3])
    %Runner{program: program,
            state: %Levels{map_by_ids: %{1 => %{state: %{"space" => 3}},...}, ...} }
  """
  def change_other_state(%Runner{} = runner_state, [target, var, op, value]) do
    target = resolve_variable(runner_state, target)
    value = resolve_variable(runner_state, value)

    _change_state(runner_state, target, var, op, value)
  end

  @immutable_player_state_variables ["player" , "equipped", "equipment" | PlayerInstance.stats()]

  defp _change_state(%Runner{state: state} = runner_state, %{} = target, var, op, value) do
    if(target.state["player"] &&
        (Enum.member?(@immutable_player_state_variables, var)) || String.ends_with?(to_string(var), "_key")) do
      runner_state
    else
      update_var = %{ var => Maths.calc(target.state[var] || 0, op, value) }
      {_updated_target, updated_state} = Levels.update_tile_state(state, target, update_var)
      %Runner{ runner_state | state: updated_state }
    end
  end

  defp _change_state(%Runner{object_id: object_id, state: state} = runner_state, target, var, op, value) do
    target_tile = if is_integer(target) || is_binary(target) && String.starts_with?(target, "new") do
                    Levels.get_tile_by_id(state, %{id: target})
                  else
                    object = Levels.get_tile_by_id(state, %{id: object_id})
                    Levels.get_tile(state, object, target)
                  end

    _change_state(runner_state, target_tile, var, op, value)
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
            state: %Levels{map_by_ids: %{object_id => %{object | row: object.row - 1}}}}
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
            state: %Levels{ map_by_ids: %{object_id => %{ object | state: %{"wait_cycles" => 1} } } } }
  """
  def cycle(runner_state, [wait_cycles]) do
    if wait_cycles < 1 do
      runner_state
    else
      change_state(runner_state, ["wait_cycles", "=", wait_cycles])
    end
  end

  @doc """
  Kills the script for the object. Returns a dead program, and deletes the object from the instance state

  ## Examples

    iex> Command.die(%Runner{program: program,
                             object_id: object_id,
                             state: %Levels{ map_by_ids: %{object_id => %{ script: ... } } }}
    %Runner{program: %{program | pc: -1, status: :dead},
            object_id: object_id,
            state: %Levels{ map_by_ids: %{ ... } } }
  """
  def die(%Runner{program: program, object_id: object_id, state: state} = runner_state, _ignored \\ nil) do
    {deleted_object, updated_state} = Levels.delete_tile(state, %{id: object_id})

    if deleted_object.state["player"] do
      terminate(runner_state)
    else
      %Runner{runner_state |
              program: %{program | status: :dead, pc: -1},
              state: updated_state}
    end
  end

  @doc """
  Give a tile an equippable item. This will add the item slug to the tiles `equipment` list,
  but does not set it as `equipped`. If the item_slug is invalid, this command will
  do nothing. The third and fourth parameters are optional, but the fourth parameter requires the third.
  The first parameter is the item_slug, second parameter is whom to give the equipment.
  The third parameter is the max number of that equipment the tile may have, and the fourth
  is the label to jump to if the tile is at the max number.

  ## Examples

     iex> equip(%Runner{}, ["healing_potion", [:event_sender]])
     %Runner{}

     iex> equip(%Runner{}, ["healing_potion", [:event_sender], 1])
     %Runner{}

     iex> equip(%Runner{}, ["healing_potion", [:event_sender], 1, "ALREADY_HAVE"])
     %Runner{}
  """
  def equip(%Runner{} = runner_state, [what, to_whom]) do
    _equip(runner_state, [what, to_whom, nil, nil])
  end

  def equip(%Runner{} = runner_state, [what, to_whom, max]) do
    _equip(runner_state, [what, to_whom, max, nil])
  end

  def equip(%Runner{} = runner_state, [what, to_whom, max, label]) do
    _equip(runner_state, [what, to_whom, max, label])
  end

  defp _equip(%Runner{} = runner_state, [%Item{} = what, target, max, label]) do
    _via_helper(runner_state, %{what: what, target: target, max: max, label: label}, &_equip_via_id/2)
  end

  defp _equip(%Runner{state: state} = runner_state, [what, to_whom, max, label]) do
    item_slug = resolve_variable(runner_state, what)

    case Levels.get_item(item_slug, state) do
      {item, _state, :exists} -> _equip(runner_state, [item, to_whom, max, label])
      {item, state, :created} -> _equip(%{runner_state | state: state}, [item, to_whom, max, label])
      _ -> runner_state
    end
  end

  defp _equip_via_id(%Runner{state: state, program: program} = runner_state, data) do
    %{what: item, target: id, max: max, label: label} = data
    max = resolve_variable(runner_state, max)
    receiver = Levels.get_tile_by_id(state, %{id: id})

    count = receiver && Enum.reduce(receiver.state["equipment"] || [], 0,
                          fn(i,acc) -> if i == item.slug, do: acc + 1, else: acc end)
              || 0

    cond do
      receiver && count < max ->
        updated_equipment = [ item.slug | receiver.state["equipment"] || [] ]

        {_receiver, state} = Levels.update_tile_state(state, receiver, %{"equipment" => updated_equipment})

        %{ runner_state | state: state }

      label ->
        updated_program = %{ runner_state.program | pc: Program.line_for(program, label), status: :wait, wait_cycles: 1 }
        %{ runner_state | state: state, program: updated_program }

      true ->
        runner_state
    end
  end

  @doc """
  The gameover command. This triggers the end of the game, and records scores when applicable.
  The three parameters are optional, the first being a boolean for victory (true) or loss (false),
  the second is the result the scores will be recorded as (ie, Win, Lose, etc, defaults as "Win") and
  is really a more wordy version of the first parameter but could be used to specify different win or lose
  conditions.
  The third is player(s) for which this command will end the game.
  Only three valid values `?sender`, a player tile id, or `all`. Defaults to the event sender, which will end
  the game will be ended for only that player. When `all`, the game ends for all players in the dungeon.

  ## Examples

    iex> Command.gameover(%Runner{}, [false, "Loss"])
    %Runner{}

    iex> Command.gameover(%Runner{}, [false, "Loss", [:event_sender]])
    %Runner{}
  """
  def gameover(runner_state, params, instance_module \\ Levels)
  def gameover(%Runner{} = runner_state, [""], instance_module) do
    _gameover(runner_state, [true, "Win", [:event_sender]], instance_module)
  end

  def gameover(%Runner{} = runner_state, [victory], instance_module) do
    _gameover(runner_state, [victory, "Win", [:event_sender]], instance_module)
  end

  def gameover(%Runner{} = runner_state, [victory, result], instance_module) do
    _gameover(runner_state, [victory, result, [:event_sender]], instance_module)
  end

  def gameover(%Runner{} = runner_state, [victory, result, who], instance_module) do
    _gameover(runner_state, [victory, result, who], instance_module)
  end

  def _gameover(%Runner{event_sender: event_sender} = runner_state, [victory, result, [:event_sender]], instance_module) do
    case event_sender do
      %Location{tile_instance_id: id} -> _gameover(runner_state, [victory, result, id], instance_module)

      _nil              -> runner_state
    end
  end

  def _gameover(%Runner{state: state} = runner_state, [victory, result, "all"], instance_module) do
    # Cast endgame to the other instance processes
    {:ok, dungeon_instance_registry} = Registrar.instance_registry(state.dungeon_instance_id)
    LevelRegistry.flat_list(dungeon_instance_registry)
    |> Enum.each(fn {_, pid} -> LevelProcess.gameover(pid, victory, result, instance_module) end)

    runner_state
  end

  def _gameover(%Runner{state: state} = runner_state, [victory, result, id], instance_module) do
    if player_tile_id = resolve_variable(runner_state, id) do
      %{ runner_state | state: instance_module.gameover(state, player_tile_id, victory, result) }
    else
      runner_state
    end
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

    iex> Command.give(%Runner{}, ["cash", 420, [:event_sender]])
    %Runner{}
    iex> Command.give(%Runner{}, ["ammo", {:state_variable, "rounds"}, "north"])
    %Runner{}
    iex> Command.give(%Runner{}, ["health", 100, "north", 100, "HEALEDUP"])
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

  defp _give(%Runner{} = runner_state, [what, amount, target, max, label]) do
    _via_helper(runner_state, %{what: what, amount: amount, target: target, max: max, label: label}, &_give_via_id/2)
  end

  defp _give_via_id(%Runner{state: state, program: program} = runner_state, data) do
    %{what: what, amount: amount, target: id, max: max, label: label} = data
    amount = resolve_variable(runner_state, amount)
    what = resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      max = resolve_variable(runner_state, max)
      receiver = Levels.get_tile_by_id(state, %{id: id})
      current_value = receiver && receiver.state[what] || 0
      adjusted_amount = _adjust_amount_to_give(amount, max, current_value)
      new_value = current_value + adjusted_amount

      cond do
        receiver && adjusted_amount > 0 ->
          {_receiver, state} = Levels.update_tile_state(state, receiver, %{what => new_value})

          if state.player_locations[id] do
            payload = %{stats: PlayerInstance.current_stats(state, %Tile{id: id})}
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
            state: %Levels{map_by_ids: %{object_id => %{object | row: object.row - 1}}}}
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
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = Direction.change_direction(object.state["facing"], change)
    _facing(runner_state, direction)
  end
  def facing(%Runner{object_id: object_id, state: state} = runner_state, [target]) do
    direction = if is_integer(target) || is_binary(target) && String.starts_with?(target, "new") do
                  object = Levels.get_tile_by_id(state, %{id: object_id})
                  if target_tile = Levels.get_tile_by_id(state, %{id: target}) do
                    Levels.direction_of_tile(state, object, target_tile)
                  else
                    nil
                  end
                else
                  target
                end
    if direction do
      _facing(runner_state, direction)
    else
      runner_state
    end
  end
  def _facing(runner_state, direction) do
    runner_state = change_state(runner_state, ["facing", "=", direction])
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
  def jump_if(%Runner{} = runner_state, [check, label_or_skip]) do
    check = _decompose_and_check_conditional(runner_state, check)
    _jump_if(runner_state, check, label_or_skip)
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

  defp _decompose_and_check_conditional(runner_state, [neg, left, op, right]) do
    Maths.check(neg, resolve_variable(runner_state, left), op, resolve_variable(runner_state, right))
  end
  defp _decompose_and_check_conditional(runner_state, [left, op, right]) do
    _decompose_and_check_conditional(runner_state, ["", left, op, right])
  end
  defp _decompose_and_check_conditional(runner_state, [neg, left]) do
    _decompose_and_check_conditional(runner_state, [neg, left, "==", :truthy])
  end
  defp _decompose_and_check_conditional(runner_state, left) do
    _decompose_and_check_conditional(runner_state, ["", left, "==", :truthy])
  end

  @doc """
  Locks the object. This will prevent it from receiving and acting on any
  message/event until it is unlocked. The underlying state value `locked`
  can also be directly set via the state shorthand `@`.

  ## Examples

    iex> Command.lock(%Runner{}, [])
    %Runner{program: program,
            object_id: object_id,
            state: %Levels{by_map_ids: %{object_id => %{ object | state: %{"locked" => true}} }} }
  """
  def lock(runner_state, _) do
    change_state(runner_state, [:locked, "=", true])
  end

  @doc """
  Moves the associated tile/object based in the direction given by the first parameter.
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
            state: %Levels{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def move(%Runner{program: program, object_id: object_id, state: state} = runner_state, ["idle", _]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    %{ runner_state | program: %{program | status: :wait, wait_cycles: StateValue.get_int(object, "wait_cycles", 5) } }
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
    object = Levels.get_tile_by_id(state, %{id: object_id})
    %{ runner_state | program: %{program | pc: next_actions.pc,
                                                 lc: next_actions.lc,
                                                 status: :wait,
                                                 wait_cycles: StateValue.get_int(object, "wait_cycles", 5) }}
  end
  defp _move(%Runner{object_id: object_id, state: state} = runner_state, direction, retryable, next_actions, move_func) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)

    destination = Levels.get_tile(state, object, direction)

    %Runner{program: program, state: state} = runner_state

    case move_func.(object, destination, state) do
      {:ok, _tile_changes, new_state} ->
        updated_runner_state = %Runner{ runner_state |
                                        program: %{program | pc: next_actions.pc,
                                                             lc: next_actions.lc,
                                                             status: :wait,
                                                             wait_cycles: object.state["wait_cycles"] || 5 },
                                        state: new_state}
        change_state(updated_runner_state, ["facing", "=", direction])

      {:invalid, _tile_changes, new_state} ->
        next_actions.invalid_move_handler.(%{runner_state | state: new_state}, destination, retryable)
    end
  end

  defp _get_real_direction(object, {:state_variable, var}) do
    object.state[var] || "idle"
  end
  defp _get_real_direction(object, "continue") do
    object.state["facing"] || "idle"
  end
  defp _get_real_direction(_object, direction), do: direction || "idle"

  defp _invalid_compound_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, blocking_obj, retryable) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, "wait_cycles", 5)
    cond do
      Program.line_for(program, "THUD") ->
        sender = if blocking_obj, do: %{tile_id: blocking_obj.id, state: blocking_obj.state, name: blocking_obj.name},
                                  else: %{tile_id: nil, state: %{}}
        program = %{program | status: :wait, wait_cycles: wait_cycles}
        %{ runner_state |
             program: Program.send_message(program, "THUD", sender, 0) }

      retryable ->
          %{ runner_state | program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: wait_cycles} }
      true ->
          %{ runner_state | program: %{program | pc: program.pc - 1, lc: program.lc + 1,  status: :wait, wait_cycles: wait_cycles} }
    end
  end

  defp _invalid_simple_command(%Runner{program: program, object_id: object_id, state: state} = runner_state, blocking_obj, retryable) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    wait_cycles = StateValue.get_int(object, "wait_cycles", 5)
    cond do
      Program.line_for(program, "THUD") ->
        sender = if blocking_obj, do: %{tile_id: blocking_obj.id, state: blocking_obj.state, name: blocking_obj.name},
                                  else: %{tile_id: nil, state: %{}}
        program = %{program | status: :wait, wait_cycles: wait_cycles}
        %{ runner_state |
             program: Program.send_message(program, "THUD", sender, 0) }

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
  Registers the tile as a passage exit. Parameter is the passage identifier that will be used to find
  it when the TRANSPORT command is invoked. The parameter can be a literal value, or it can be a state variable
  such as the objects color.

  ## Examples

    iex> Command.passage(%Runner{object_id: object_id}, [{:state_variable, "background_color"}])
    %Runner{ state: %Levels{..., passage_exits: [{object_id, {:state_variable, "background_color"}}] } }

    iex> Command.passage(%Runner{object_id: object_id}, ["door1"])
    %Runner{ state: %Levels{..., passage_exits: [{object_id, "door1"}] } }
  """
  def passage(%Runner{state: state, object_id: object_id} = runner_state, [match_key]) do
    match_key = resolve_variable(runner_state, match_key)
    %{ runner_state | state: %{ state | passage_exits: [ {object_id, match_key} | state.passage_exits] } }
  end

  @doc """
  Similar to the TRY command. The main difference is that the object will pull an adjacent tile into its
  previous location if able. If the pulled tile has the state value `pulling` set then that tile may also pull an
  adjacent tile to where it was (this can be chained).

  See the `move` command for valid directions.

  ## Examples

    iex> Command.pull(%Runner{program: %Program{},
                              object_id: object_id,
                              state: state},
                      ["north"])
    %Runner{program: %{ program | status: :wait, wait_cycles: 5 },
            state: %Levels{ map_by_ids: %{object_id => %{object | row: object.row - 1},
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
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)
    range = resolve_variable(runner_state, range)

    {row_d, col_d} = Direction.delta(direction)

    _push(runner_state, object, direction, {row_d, col_d}, range)
  end

  defp _push(%Runner{state: state} = runner_state, object, direction, {row_d, col_d}, range) when range >= 0 do
    case Levels.get_tiles(state, %{row: object.row + row_d * range, col: object.col + col_d * range}) do
      nil ->
        _push(runner_state, object, direction, {row_d, col_d}, range - 1)

      pushees ->
        Enum.reduce(pushees, runner_state, fn(pushee, runner_state) ->
          case pushee.state["pushable"] &&
               pushee.id != object.id &&
               Move.go(pushee, Levels.get_tile(state, pushee, direction), state) do
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
  If both `row` and `col` are not given, then neither are used. If the specified location or direction is invalid/off the level,
  then nothing is done.
  Other kwargs can be given, such as name, character, color, background color, and will override the values from
  the matching tile template. Other values not mentioned above will set state values.
  Reference variables can be used instead of literals; however if they resolve to invalid values, then
  this command will do nothing.

  Changes will be persisted to the database, and that coordinate will be marked for rerendering.

  ## Examples

    iex> Command.put(%Runner{}, [%{slug: "banana", direction: "north"}])
    %Runner{program: %{program |
            object_id: object_id,
            state: updated_state }
    iex> Command.put(%Runner{}, [%{clone:  {:state_variable, "clone_id"}, direction:  {:state_variable, "facing"}}])
    %Runner{}
  """
  def put(%Runner{state: state} = runner_state, [%{"clone" => clone_tile} = params]) do
    params = resolve_variables(runner_state, params)
    clone_tile = resolve_variable(runner_state, clone_tile)
    clone_base_tile = Levels.get_tile_by_id(state, %{id: clone_tile})

    if clone_base_tile do
      attributes = _tile_template_copy_fields(clone_base_tile)
                   |> Map.merge(resolve_variables(runner_state, Map.take(params, ["name", "character", "color", "background_color"])))
      new_state_attrs = resolve_variables(runner_state,
                                             Map.take(params, Map.keys(params) -- (_tile_template_keys() ++ ["direction", "shape", "clone"] )))
      _put(runner_state, attributes, params, new_state_attrs)
    else
      runner_state
    end
  end

  def put(%Runner{} = runner_state, [%{"slug" => _slug} = params]) do
    params = resolve_variables(runner_state, params)
    {slug_tile, runner_state} = _get_tile_template(runner_state, params["slug"])

    if slug_tile do
      attributes = _tile_template_copy_fields(slug_tile)
                   |> Map.merge(resolve_variables(runner_state, Map.take(params, ["name", "character", "color", "background_color"])))
      new_state_attrs = resolve_variables(runner_state,
                                             Map.take(params, Map.keys(params) -- (_tile_template_keys() ++ ["direction", "shape"] )))

      _put(runner_state, attributes, params, new_state_attrs)
    else
      runner_state
    end
  end

  defp _put(%Runner{object_id: object_id, state: state} = runner_state, attributes, %{"shape" => shape} = params, new_state_attrs) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, params["direction"])
    bypass_blocking = if is_nil(params["bypass_blocking"]), do: "soft", else: params["bypass_blocking"]

    case shape do
      "line" ->
        include_origin = if is_nil(params["include_origin"]), do: false, else: params["include_origin"]
        Shape.line(runner_state, direction, params["range"], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "cone" ->
        include_origin = if is_nil(params["include_origin"]), do: false, else: params["include_origin"]
        Shape.cone(runner_state, direction, params["range"], params["width"] || params["range"], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "circle" ->
        include_origin = if is_nil(params["include_origin"]), do: true, else: params["include_origin"]
        Shape.circle(runner_state, params["range"], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      "blob" ->
        include_origin = if is_nil(params["include_origin"]), do: false, else: params["include_origin"]
        Shape.blob(runner_state, params["range"], include_origin, bypass_blocking)
        |> _put_shape_tiles(runner_state, object, attributes, new_state_attrs)

      _ ->
        runner_state
    end
  end

  defp _put(%Runner{object_id: object_id, state: state} = runner_state, attributes, params, new_state_attrs) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, params["direction"])

    {row_d, col_d} = Direction.delta(direction)

    coords = if params["row"] && params["col"] do
               %{"row" => params["row"] + row_d, "col" => params["col"] + col_d}
             else
               %{"row" => object.row + row_d, "col" => object.col + col_d}
             end

    if coords["row"] >= 0 && coords["row"] < state.state_values["rows"] &&
       coords["col"] >= 0 && coords["col"] < state.state_values["cols"] do
      new_attrs = Map.merge(attributes, Map.put(coords, "level_instance_id", object.level_instance_id))
      _put_tile(runner_state, new_attrs, new_state_attrs)
    else
      runner_state
    end
  end

  defp _put_tile(%Runner{state: state} = runner_state, tile_attrs, new_state_attrs) do
    z_index = if target_tile = Levels.get_tile(state, tile_attrs), do: target_tile.z_index + 1, else: 0
    tile_attrs = Map.put(tile_attrs, "z_index", z_index)

    case DungeonCrawl.DungeonInstances.new_tile(tile_attrs) do
      {:ok, new_tile} -> # all that other stuff below
        {new_tile, state} = Levels.create_tile(state, new_tile)
        {_new_tile, state} = Levels.update_tile_state(state, new_tile, new_state_attrs)
        %{ runner_state | state: state }

      {:error, _} ->
        runner_state
    end
  end

  defp _put_shape_tiles(coords, %Runner{} = runner_state, object, attributes, new_state_attrs) do
    coords
    |> Enum.reduce(runner_state, fn({row, col}, runner_state) ->
         loc_attrs = %{"row" => row, "col" => col, "level_instance_id" => object.level_instance_id}
         _put_tile(runner_state, Map.merge(attributes, loc_attrs), new_state_attrs)
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
    %Runner{ state: %{...object => %{state => %{foo: 2} } } }
    iex> Command.random(%Runner{}, ["foo", "one", "two", "three"])
    %Runner{ state: %{...object => %{state => %{foo: "three"} } }
  """
  def random(%Runner{} = runner_state, [state_variable | values]) do
    random_value = if length(values) == 1 and Regex.match?(~r/^\d+\s?-\s?\d+$/, Enum.at(values,0)) do
                      [lower, upper] = String.split( Enum.at(values, 0), ~r/\s*-\s*/)
                                       |> Enum.map(&String.to_integer/1)
                      Enum.random(lower..upper)
                    else
                      Enum.random(values)
                    end
    _random(runner_state, state_variable, random_value)
  end

  def _random(runner_state, {:instance_state_variable, state_variable}, random_value),
    do: change_level_instance_state(runner_state, [state_variable, "=", random_value])
  def _random(runner_state, {:dungeon_instance_state_variable, state_variable}, random_value),
    do: change_dungeon_instance_state(runner_state, [state_variable, "=", random_value])
  def _random(runner_state, {:state_variable, state_variable}, random_value),
    do: change_state(runner_state, [state_variable, "=", random_value])
  def _random(runner_state, state_variable, random_value),
    do: change_state(runner_state, [state_variable, "=", random_value])

  @doc """
  Replaces a tile. Uses KWARGs, `target` and attributes prefixed with `target_` can be used to specify which tiles to replace.
  `target` can be the name of a tile, or a direction. The other `target_` attributes must also match along with the `target`.
  At least one attribute or slug KWARG should be used to specify what to replace the targeted tile with. If there are many tiles with
  that name, then all those tiles will be replaced. For a direction, only the top tile will be removed when there are more
  than one tiles there.
  If there are no tiles matching, nothing is done. Player tiles will not be replaced.
  """
  def replace(%Runner{} = runner_state, [params]) do
    [target_conditions, new_params] = params
                                      |> Enum.map(fn
                                           {k, v} when is_atom(k) -> {Atom.to_string(k), resolve_variable(runner_state, v)}
                                           {k, v} -> {k, resolve_variable(runner_state, v)}
                                         end)
                                      |> Enum.split_with( fn {k,_} -> Regex.match?( ~r/^target/, k ) end )
                                      |> Tuple.to_list
                                      |> Enum.map(fn partition ->
                                           Enum.map(partition, fn {k, v} -> {String.replace_leading(k, "target_", ""), v} end)
                                           |> Enum.into(%{})
                                         end)
    _replace(runner_state, target_conditions, new_params)
  end

  defp _replace(%Runner{state: state} = runner_state, target_conditions, new_params) do
    {target, target_conditions} = Map.pop(target_conditions, "target")
    target = if is_binary(target), do: String.downcase(target), else: target

    if Direction.valid_orthogonal?(target) do
      _replace_in_direction(runner_state, target, target_conditions, new_params)
    else
      tile_ids = state.map_by_ids
                 |> Map.to_list
                 |> _filter_tiles_with(target, target_conditions)
                 |> Enum.map(fn {id, _tile} -> id end)
      _replace_via_ids(runner_state, tile_ids, new_params)
    end
  end

  defp _replace_in_direction(%Runner{state: state, object_id: object_id} = runner_state, direction, target_conditions, new_params) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    tile = Levels.get_tile(state, object, direction)

    if tile && Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _tile_value(tile, key) == val end) do
      _replace_via_ids(runner_state, [tile.id], new_params)
    else
      runner_state
    end
  end

  defp _replace_via_ids(runner_state, [], _new_params), do: runner_state
  defp _replace_via_ids(%Runner{state: state, program: program} = runner_state, [id | ids], new_params) do
    if Levels.is_player_tile?(state, %{id: id}) do
      _replace_via_ids(runner_state, ids, new_params)
    else
      %Runner{program: other_program, state: state} = become(%{runner_state | object_id: id}, [new_params])
      _replace_via_ids(%{runner_state | state: state, program: %{ program | broadcasts: other_program.broadcasts}}, ids, new_params)
    end
  end

  @tile_value_ecto_attrs %{
    "background_color" => :background_color,
    "character" => :character,
    "col" => :col,
    "color" => :color,
    "id" => :id,
    "name" => :name,
    "row" => :row,
    "z_index" => :z_index
  }

  defp _tile_value(tile, key) do
    if mapped_key = @tile_value_ecto_attrs[key] do
      Map.get(tile, mapped_key)
    else
      tile.state[key]
    end
  end

  defp _filter_tiles_with(_tile_map, nil, %{} = target_conditions) when map_size(target_conditions) == 0, do: []

  defp _filter_tiles_with(tile_map, nil, target_conditions) do
    tile_map
    |> Enum.filter(fn {_id, tile} ->
         Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _tile_value(tile, key) == val end)
       end)
  end

  defp _filter_tiles_with(tile_map, target, target_conditions) do
    tile_map
    |> Enum.filter(fn {_id, tile} ->
         String.downcase(tile.name || "") == target &&
           Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _tile_value(tile, key) == val end)
       end)
  end

  @doc """
  Removes a tile. Uses kwargs, the `target` KWARG in addition to other attribute targets may be used.
  Valid targets are a direction, or the name (case insensitive) of a tile. If there are many tiles with
  that name, then all those tiles will be removed. For a direction, only the top tile will be removed when there are more
  than one tile there. If there are no tiles matching, nothing is done.
  Player tiles will not be removed.
  """
  def remove(%Runner{} = runner_state, [params]) do
    target_conditions = params
                        |> Enum.map(fn
                              # there might be something saved legacy that is an atom
                              {k, v} when is_atom(k) ->
                                { Atom.to_string(k) |> String.replace_leading( "target_", ""),
                                  resolve_variable(runner_state, v) }
                              {k, v} ->
                                { String.replace_leading(k, "target_", ""),
                                  resolve_variable(runner_state, v) }
                           end)
                        |> Enum.into(%{})

    _remove(runner_state, target_conditions)
  end

  def _remove(%Runner{state: state} = runner_state, target_conditions) do
    {target, target_conditions} = Map.pop(target_conditions, "target")
    target = if target, do: String.downcase(target), else: nil

    if Direction.valid_orthogonal?(target) do
      _remove_in_direction(runner_state, target, target_conditions)
    else
      tile_ids = state.map_by_ids
                 |> Map.to_list
                 |> _filter_tiles_with(target, target_conditions)
                 |> Enum.map(fn {id, _tile} -> id end)
      _remove_via_ids(runner_state, tile_ids)
    end
  end

  defp _remove_in_direction(%Runner{state: state, object_id: object_id} = runner_state, direction, target_conditions) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    tile = Levels.get_tile(state, object, direction)

    if tile && Enum.reduce(target_conditions, true, fn {key, val}, acc -> acc && _tile_value(tile, key) == val end) do
      _remove_via_ids(runner_state, [tile.id])
    else
      runner_state
    end
  end

  defp _remove_via_ids(runner_state, []), do: runner_state
  defp _remove_via_ids(%Runner{state: state} = runner_state, [id | ids]) do
    if Levels.is_player_tile?(state, %{id: id}) do
      _remove_via_ids(runner_state, ids)
    else
      {_deleted_object, updated_state} = Levels.delete_tile(state, %{id: id})

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
  The third (optional) param is the delay in seconds from when the command runs to actually
  trigger the event.

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

  The special varialble `?sender` can be used to send the message to the program
  that sent the event.
  """
  def send_message(%Runner{} = runner_state, [label]), do: send_message(runner_state, [label, "self", 0])
  def send_message(%Runner{} = runner_state, [label, target]), do: send_message(runner_state, [label, target, 0])
  def send_message(%Runner{object_id: object_id, state: state} = runner_state, [label, {:state_variable, var}, delay]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    _send_message(runner_state, [label, object.state[var], delay])
  end
  def send_message(%Runner{event_sender: event_sender} = runner_state, [label, [:event_sender], delay]) do
    case event_sender do
      %{tile_id: id} -> _send_message_via_ids(runner_state, label, delay, [id]) # basic tile
      %{tile_instance_id: id} -> _send_message_via_ids(runner_state, label, delay, [id]) # player tile
      # Right now, if the actor was a player, this does nothing. Might change later.
      _                  -> runner_state
    end
  end
  def send_message(%Runner{} = runner_state, [label, target, delay]) do
    target = if is_binary(target), do: String.downcase(target), else: target
    _send_message(runner_state, [label, target, delay])
  end

  defp _send_message(%Runner{object_id: object_id, state: state} = runner_state, [label, "global", delay]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    sender = %{tile_id: nil, state: Map.put(object.state, "global_sender", true), name: object.name}

    {:ok, dungeon_instance_registry} = Registrar.instance_registry(state.dungeon_instance_id)
    LevelRegistry.flat_list(dungeon_instance_registry)
    |> Enum.each(fn {_, pid} -> LevelProcess.send_event(pid, label, sender, delay) end)

    runner_state
  end
  defp _send_message(%Runner{state: state, object_id: object_id} = runner_state, [label, "self", 0]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    %{ runner_state | state: %{ state | program_messages: [ {object.id, label, %{tile_id: object.id, state: object.state}} |
                                                            state.program_messages] } }
  end
  defp _send_message(%Runner{state: state, program: program, object_id: object_id} = runner_state, [label, "self", delay]) do
    trigger_time = DateTime.utc_now |> DateTime.add(delay, :second)
    object = Levels.get_tile_by_id(state, %{id: object_id})
    timed_messages = Enum.reverse([
        {trigger_time, label, %{tile_id: object.id, state: object.state}}
        | Enum.reverse(program.timed_messages)
      ])
    %{ runner_state | program: %{ program | timed_messages: timed_messages } }
  end
  defp _send_message(%Runner{state: state, object_id: object_id} = runner_state, [label, "others", delay]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    _send_message_id_filter(runner_state, label, delay, fn object_id -> object_id != object.id end)
  end
  defp _send_message(%Runner{} = runner_state, [label, "all", delay]) do
    _send_message_id_filter(runner_state, label, delay, fn _object_id -> true end)
  end
  defp _send_message(%Runner{} = runner_state, [label, target, delay]) when target == "here" do
    _send_message_in_direction(runner_state, label, target, delay)
  end
  defp _send_message(%Runner{} = runner_state, [label, target, delay]) when is_valid_orthogonal(target) do
    _send_message_in_direction(runner_state, label, target, delay)
  end
  defp _send_message(%Runner{state: state} = runner_state, [label, target, delay]) do
    if is_integer(target) || is_binary(target) && String.starts_with?(target, "new") do
      _send_message_via_ids(runner_state, label, delay, [target])
    else
      tile_ids = state.map_by_ids
                 |> Map.to_list
                 |> Enum.filter(fn {_id, tile} -> String.downcase(tile.name || "") == target end)
                 |> Enum.map(fn {id, _tile} -> id end)
      _send_message_via_ids(runner_state, label, delay, tile_ids)
    end
  end

  defp _send_message_in_direction(%Runner{state: state, object_id: object_id} = runner_state, label, direction, delay) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    tile_ids = Levels.get_tiles(state, object, direction)
               |> Enum.map(&(&1.id))
    _send_message_via_ids(runner_state, label, delay, tile_ids)
  end

  defp _send_message_id_filter(%Runner{state: state} = runner_state, label, delay, filter) do
    program_object_ids = state.program_contexts
                         |> Map.keys()
                         |> Enum.filter(&filter.(&1))
    _send_message_via_ids(runner_state, label, delay, program_object_ids)
  end

  defp _send_message_via_ids(%Runner{event_sender: %Location{} = event_sender} = runner_state, label, delay, program_object_ids) do
    _send_message_via_ids(runner_state, label, event_sender, delay, program_object_ids)
  end
  defp _send_message_via_ids(%Runner{state: state, object_id: object_id} = runner_state, label, delay, program_object_ids) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    event_sender = %{tile_id: object_id, state: object.state, name: object.name}
    _send_message_via_ids(runner_state, label, event_sender, delay, program_object_ids)
  end

  defp _send_message_via_ids(runner_state, _label, _event_sender, _delay, []), do: runner_state
  defp _send_message_via_ids(%Runner{state: state} = runner_state, label, event_sender, 0, [po_id | program_object_ids]) do
    _send_message_via_ids(
      %{ runner_state | state: %{ state | program_messages: [ {po_id, label, event_sender} | state.program_messages] } },
      label,
      0,
      program_object_ids
    )
  end
  defp _send_message_via_ids(%Runner{state: state} = runner_state, label, event_sender, delay, [po_id | program_object_ids]) do
    _send_message_via_ids(
      %{ runner_state | state: %{ state | program_messages: [{po_id, label, event_sender, delay} | state.program_messages] } },
      label,
      delay,
      program_object_ids
    )
  end

  @doc """
  Sets the specified state variable to the next value in the given sequence. The first parameter is the
  state variable, and the subsequent parameters are the sequence values. As a side effect this will
  update the instruction and move the HEAD element of the sequence to the tail.

  ## Examples

    iex> Command.sequence(%Runner{}, ["foo", "red", "yellow", "blue"])
    %Runner{ state: %{...object => %{state => %{foo: "red"} } },
             program: %{instructions: %{program.pc => [:sequence, ["foo", ["yellow", "blue", "red"]] ] } }
  """
  def sequence(%Runner{} = runner_state, [state_variable | [head | tail]]) do
    runner_state = change_state(runner_state, [state_variable, "=", head])

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
    object = Levels.get_tile_by_id(state, %{id: object_id})

    shiftables = _shift_coords(direction, _shift_adj_coords())
                 |> Enum.map(fn({{row_d, col_d}, {dest_row_d, dest_col_d}}) ->
                      { Levels.get_tile(state, %{row: object.row + row_d, col: object.col + col_d}),
                        Levels.get_tile(state, %{row: object.row + dest_row_d, col: object.col + dest_col_d}) }
                    end)
                 |> Enum.filter(fn({tile, _dest_tile}) -> tile && tile.state["pushable"] && !state.shifted_ids[tile.id] end)
                 |> Enum.reject(fn({_tile, dest_tile}) -> !dest_tile || dest_tile.state["blocking"] && !dest_tile.state["pushable"] end)

    {runner_state, _, tile_changes} = _shifting(runner_state, shiftables, %{})

    # TODO: see if Move.go needs the {row, col} return anymore, or if it can be swapped with %{row: _, col: _}
    rerender_coords = tile_changes
                      |> Map.to_list
                      |> Enum.map(fn { {row, col}, _tile } -> %{row: row, col: col} end)
                      |> Enum.reduce(state.rerender_coords, fn coords, rerender_coords -> Map.put(rerender_coords, coords, true) end)

    %Runner{ runner_state |
             state: %{ runner_state.state |
               rerender_coords: rerender_coords,
               shifted_ids: Map.merge(runner_state.state.shifted_ids, _shifted_tile_id_map(shiftables, tile_changes)) },
             program: %{program |
                        status: :wait,
                        wait_cycles: object.state["wait_cycles"] || 5 } }
  end

  defp _shifting(%Runner{} = runner_state, [], tile_changes), do: {runner_state, [], tile_changes}
  defp _shifting(%Runner{} = runner_state, shiftables, tile_changes) do
    {runner_state, shifts_pending, tile_changes} = _shifting(runner_state, shiftables, [], tile_changes)

    if length(shifts_pending) == length(shiftables) do
      {runner_state, [], tile_changes}
    else
      refreshed_shifts_pending = Enum.reverse(shifts_pending)
                               |> Enum.map(fn({tile, dest_tile}) -> {tile, Levels.get_tile(runner_state.state, dest_tile)} end)

      _shifting(runner_state, refreshed_shifts_pending, tile_changes)
    end
  end

  defp _shifting(%Runner{} = runner_state, [], shifts_pending, tile_changes), do: {runner_state, shifts_pending, tile_changes}
  defp _shifting(%Runner{state: state} = runner_state, [{tile, dest_tile} | other_pairs], shifts_pending, tile_changes) do
    if dest_tile.state["blocking"] do
      _shifting(runner_state, other_pairs, [ {tile, dest_tile} | shifts_pending], tile_changes)
    else
      {_, tile_changes, state} = Move.go(tile, dest_tile, state, tile_changes, true)
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

  defp _shifted_tile_id_map(shiftables, tile_changes) do
    rerender_ids = Enum.map(tile_changes, fn {_coord, tile} -> tile.id end)

    shiftables
    |> Enum.map(fn {tile, _dest} -> {tile.id, true} end)
    |> Enum.reject(fn {tile_id, _} -> !Enum.member?(rerender_ids, tile_id) end)
    |> Enum.into(%{})
  end

  @doc """
  Fires a bullet in the given direction. The bullet will spawn on the same tile as the object.
  The bullet will walk in given direction until it hits something, or something
  responds to the "SHOT" message.
  """
  def shoot(%Runner{state: state, object_id: object_id} = runner_state, [{:state_variable, var}]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    shoot(runner_state, [object.state[var]])
  end
  def shoot(%Runner{} = runner_state, ["player"]) do
    {new_runner_state, player_direction} = _direction_of_player(runner_state)
    shoot(new_runner_state, [player_direction])
  end
  def shoot(%Runner{object_id: object_id, state: state} = runner_state, [direction]) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    direction = _get_real_direction(object, direction)

    case Shoot.shoot(object, direction, state) do
      {:invalid} ->
        runner_state

      {:ok, updated_state} ->
        %{ runner_state | state: updated_state }
    end
  end

  @doc """
  Play a sound effect. The first parameter is the slug of the sound to play.
  This will be heard by players in the level instance.
  The second optional parameter indicates who can hear it. May be set to
  ?sender, a specific player, "all" (to play for everyone; volume constant
  on the preceeding options), or "nearby" (to only play for players close
  to the source and the further, the quieter it will be.
  Default behavior is "nearby".

  ## Examples

     iex> sound(%Runner{}, ["beep", [:event_sender]])
     %Runner{}

     iex> sound(%Runner{}, ["bloop"])
     %Runner{}

  """
  def sound(%Runner{} = runner_state, [slug]) do
    _sound(runner_state, [slug, "nearby"])
  end
  def sound(%Runner{} = runner_state, [slug, target]) do
    _sound(runner_state, [slug, target])
  end

  defp _sound(%Runner{state: state, object_id: object_id} = runner_state, [slug, target]) do
    target = resolve_variable(runner_state, target)

    with source when not is_nil(source) <- Levels.get_tile_by_id(state, %{id: object_id}),
         {sound, state, _} when not is_nil(sound) <- Levels.get_sound_effect(slug, state),
         %{"params" => zzfx_params} <- Effect.extract_params(sound) do
      effect_info = %{row: source.row,
                      col: source.col,
                      target: state.player_locations[target] || target,
                      zzfx_params: zzfx_params}
      updated_state = %{ state | sound_effects: [ effect_info | state.sound_effects]}
      %{ runner_state | state: updated_state }
    else
      _ -> runner_state
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

    iex> Command.take(%Runner{}, ["cash", :420, [:event_sender], "toopoor"])
    %Runner{}
    iex> Command.take(%Runner{}, ["ammo", {:state_variable, "rounds"}, "north"])
    %Runner{}
  """
  def take(%Runner{} = runner_state, [what, amount, from_whom]) do
    _take(runner_state, what, amount, from_whom, nil)
  end
  def take(%Runner{} = runner_state, [what, amount, from_whom, label]) do
    _take(runner_state, what, amount, from_whom, label)
  end

  defp _take(%Runner{} = runner_state, what, amount, target, label) do
    _via_helper(runner_state, %{what: what, amount: amount, target: target, label: label}, &_take_via_id/2)
  end

  defp _take_via_id(%Runner{state: state, program: program} = runner_state, data) do
    %{what: what, amount: amount, target: id, label: label} = data
    amount = resolve_variable(runner_state, amount)
    what = resolve_variable(runner_state, what)

    if is_number(amount) and amount > 0 and is_binary(what) do
      case Levels.subtract(state, what, amount, id) do
        {:ok, state} ->
          %{ runner_state | state: state }

        {:died, state} ->
          %{ runner_state | state: state }

        {_not_successful, _state} ->
          if label do
            updated_program = %{ runner_state.program | pc: Program.line_for(program, label), status: :wait, wait_cycles: 1 }
            %{ runner_state | program: updated_program }
          else
            runner_state
          end
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
    change_state(runner_state, ["target_player_map_tile_id", "=", nil])
  end

  def target_player(%Runner{} = runner_state, [what]) do
    _target_player(runner_state, String.downcase(what))
  end

  defp _target_player(%Runner{object_id: object_id, state: state} = runner_state, "nearest") do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    player_tile = \
    Map.keys(state.player_locations)
    |> Enum.map(fn(tile_id) ->
         tile = Levels.get_tile_by_id(state, %{id: tile_id})
         {Direction.distance(tile, object), tile}
       end)
    |> Enum.reduce([1000, []], fn {distance, tile}, [closest, tiles] ->
         cond do
           distance < closest ->
             [distance, [ tile ] ]

           distance == closest ->
             [closest, [ tile | tiles ]]

           true ->
             [closest, tiles]
         end
       end)
    |> Enum.at(1)
    |> Enum.random()

    change_state(runner_state, ["target_player_map_tile_id", "=", player_tile.id])
  end

  defp _target_player(%Runner{state: state} = runner_state, "random") do
    tile_ids = Map.keys(state.player_locations)
    player_tile_id = Enum.random(tile_ids)
    change_state(runner_state, ["target_player_map_tile_id", "=", player_tile_id])
  end

  defp _target_player(%Runner{} = runner_state, _), do: runner_state

  @doc """
  Kills the script for the object. Returns a dead program, and deletes the script from the object (tile instance).

  ## Examples

    iex> Command.terminate(%Runner{program: program,
                                   object_id: object_id,
                                   state: %Levels{ map_by_ids: %{object_id => %{ script: "..." } } }}
    %Runner{program: %{program | pc: -1, status: :dead},
            state: %Levels{ map_by_ids: %{object_id => %{ script: "" } } }}
  """
  def terminate(%Runner{program: program, object_id: object_id, state: state} = runner_state, _ignored \\ nil) do
    {_updated_object, updated_state} = Levels.update_tile(state, %{id: object_id}, %{script: ""})
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
  will be included after the first non empty text. The params are ignored in favor of looking up
  the line of text at the current pc, and continuing until the last sequential text message. This also
  increments the pc approprately after bundling all the messages from the text commands.

  To have an interpolated value in the text which will be computed at run time, wrap it in ${ }.

  ## Examples

    iex> Command.text(%Runner{program: program}, params: ["Door opened"])
    %Runner{ program: %{program | responses: ["Door opened"]} }
  """
  def text(%Runner{event_sender: event_sender} = runner_state, params) do
    if params != [[""]] do
      { %Runner{program: program, state: state} = runner_state, lines, labels } = _process_text(runner_state, runner_state.program.pc)

      payload = cond do
                  length(lines) == 0 ->
                    nil
                  length(lines) == 1 && ! String.contains?(Enum.at(lines, 0), "messageLink") ->
                    %{message: Enum.at(lines, 0)}
                  true ->
                    %{message: Enum.reverse(lines), modal: true}
                end

      program = if payload,
                   do: %{ program |  responses: [ {"message", payload} | program.responses] },
                   else: program

      case event_sender do
        # only care about tracking available actions sent to a player
        %Location{tile_instance_id: id} ->
          state = Levels.set_message_actions(state, id, labels)
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
      [:text, [[{:condition, conditional}, skip_lines]]] ->
        runner_state = %{runner_state | program: %{ program | pc: pc }}
        increment = if _decompose_and_check_conditional(runner_state, conditional),
                      do: 1,
                      else: skip_lines + 1

        _process_text(runner_state, pc + increment, lines, labels)

      [:text, [another_line]] ->
        runner_state = %{runner_state | program: %{ program | pc: pc }}
        safe_text = _interpolate_and_escape(another_line, runner_state)
        _process_text(runner_state, pc + 1, [ "#{ safe_text }" | lines], labels)

      [:text, [another_line, label]] ->
        runner_state = %{runner_state | program: %{ program | pc: pc }}
        safe_text = _interpolate_and_escape(another_line, runner_state)
        attrs = "class='btn-link messageLink' data-label='#{ label }' data-tile-id='#{ object_id }'"
        _process_text(runner_state, pc + 1, [ "    <span #{attrs}>▶#{ safe_text }</span>" | lines], [ String.downcase(label) | labels ])

      _ ->
        {%{ runner_state | program: _pc_to_end_of_text(program) }, lines, labels}
    end
  end

  defp _interpolate_and_escape([], _runner_state), do: ""
  defp _interpolate_and_escape([fragment | text_fragments], runner_state) do
    {:safe, safe_text} = resolve_variable(runner_state, fragment)
                         |> to_string()
                         |> html_escape()

    "#{safe_text}" <> _interpolate_and_escape(text_fragments, runner_state)
  end

  defp _pc_to_end_of_text(program) do
    case program.instructions[program.pc] do
      [:text, _] ->
        _pc_to_end_of_text(%{ program | pc: program.pc + 1})

      _ ->
        # Next run cycle will start off with the line after the last text line
        %{ program | pc: program.pc - 1}
    end
  end

  @doc """
  Transports a player tile from one level instance to another level instance that is part
  of the same dungeon. First param is the who (which should resolve to a tile id; but if its not
  a player's tile this command will do nothing).

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
      %{tile_instance_id: id} -> transport(runner_state, [id, level, match_key], travel_module) # player tile
      _                           -> runner_state
    end
  end

  def transport(%Runner{state: state} = runner_state, [who, level, match_key], travel_module) do
    tile_id = case resolve_variable(runner_state, who) do
                %{id: id} -> id
                id        -> id
              end
    level = resolve_variable(runner_state, level)
    match_key = resolve_variable(runner_state, match_key)
    player_location = Levels.get_player_location(state, %{id: tile_id})
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
    passage = Map.put(Levels.get_tile_by_id(state, %{id: object_id}) || %{}, :match_key, match_key)
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
            state: %Levels{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def try(runner_state, [direction]) do
    move(runner_state, [direction, false])
  end


  @doc """
  Takes from a tile an equippable item. This will remove the item slug from the tiles
  in the `equipment` list, and clears `equipped` if the tile no longer has any of that slug
  in its `equipment` list. If the item_slug is invalid, this command will do nothing.
  The first parameter is the item_slug, second parameter is from whom to take the equipment.
  The third parameter is the label to jump to if the tile does not have this item.

  ## Examples

     iex> unequip(%Runner{}, ["healing_potion", [:event_sender]])
     %Runner{}

     iex> unequip(%Runner{}, ["healing_potion", [:event_sender], "NO_POTION"])
     %Runner{}
  """
  def unequip(%Runner{} = runner_state, [what, to_whom]) do
    _unequip(runner_state, [what, to_whom, nil])
  end

  def unequip(%Runner{} = runner_state, [what, to_whom, label]) do
    _unequip(runner_state, [what, to_whom, label])
  end

  defp _unequip(%Runner{} = runner_state, [%Item{} = what, target, label]) do
    _via_helper(runner_state, %{what: what, target: target, label: label}, &_unequip_via_id/2)
  end

  defp _unequip(%Runner{state: state} = runner_state, [what, to_whom, label]) do
    item_slug = resolve_variable(runner_state, what)

    case Levels.get_item(item_slug, state) do
      {item, _state, :exists} -> _unequip(runner_state, [item, to_whom, label])
      {item, state, :created} -> _unequip(%{runner_state | state: state}, [item, to_whom, label])
      _ -> runner_state
    end
  end

  defp _unequip_via_id(%Runner{state: state, program: program} = runner_state, data) do
    %{what: item, target: id, label: label} = data
    loser = Levels.get_tile_by_id(state, %{id: id})

    equipment = loser.state["equipment"] || []
    updated_equipment = equipment -- [item.slug]

    count = Enum.reduce(updated_equipment, 0,
      fn(i,acc) -> if i == item.slug, do: acc + 1, else: acc end)

    cond do
      loser && count > 0 ->
        {_loser, state} = Levels.update_tile_state(state, loser, %{"equipment" => updated_equipment})
        %{ runner_state | state: state }

      loser && count == 0 && length(equipment -- updated_equipment) == 1 ->
        equipped_item = Enum.at(updated_equipment, 0)
        tile_state_changes = %{"equipment" => updated_equipment, "equipped" => equipped_item}
        {_loser, state} = Levels.update_tile_state(state, loser, tile_state_changes)
        %{ runner_state | state: state }

      label ->
        updated_program = %{ runner_state.program | pc: Program.line_for(program, label), status: :wait, wait_cycles: 1 }
        %{ runner_state | state: state, program: updated_program }

      true ->
        runner_state
    end
  end

  @doc """
  Unlocks the object. This will allow it to receive and act on any
  message/event it may receive. The underlying state value `locked`
  can also be directly set via the state shorthand `@`.

  ## Examples

    iex> Command.unlock(%Runner{}, [])
    %Runner{program: program,
            state: %Levels{map_by_ids: %{ object | state: %{"locked" => false} } }}
  """
  def unlock(runner_state, _) do
    change_state(runner_state, ["locked", "=", false])
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
            state: %Levels{ map_by_ids: %{object_id => %{object | row: object.row - 1}} }}
  """
  def walk(%Runner{program: program} = runner_state, [direction]) do
    next_actions = %{pc: program.pc - 1, lc: 0, invalid_move_handler: &_invalid_simple_command/3}
    _move(runner_state, direction, false, next_actions, &Move.go/3)
  end

  defp _direction_of_player(%Runner{object_id: object_id, state: state} = runner_state) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    target_player_tile_id = StateValue.get_int(object, "target_player_map_tile_id")
    _direction_of_player(runner_state, target_player_tile_id)
  end
  defp _direction_of_player(%Runner{state: state} = runner_state, nil) do
    with tile_ids when length(tile_ids) != 0 <- Map.keys(state.player_locations),
         player_tile_id when not is_nil(player_tile_id) <- Enum.random(tile_ids) do
      _direction_of_player(change_state(runner_state, ["target_player_map_tile_id", "=", player_tile_id]))
    else
      _ -> {change_state(runner_state, ["target_player_map_tile_id", "=", nil]), "idle"}
    end
  end
  defp _direction_of_player(%Runner{state: state, object_id: object_id} = runner_state, target_player_tile_id) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    with player_tile when player_tile != nil <- Levels.get_tile_by_id(state, %{id: target_player_tile_id}) do
      {runner_state, Levels.direction_of_tile(state, object, player_tile)}
    else
      _ ->
      _direction_of_player(change_state(runner_state, ["target_player_map_tile_id", "=", nil]))
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

  defp _via_helper(%Runner{object_id: object_id, state: state} = runner_state, %{target: target} = data, via_function) do
    target = resolve_variable(runner_state, target)
    if is_integer(target) || is_binary(target) && String.starts_with?(target, "new") do
      via_function.(runner_state, %{data | target: target})
    else
      with false <- is_nil(target),
           direction when is_valid_orthogonal(direction) <- target,
           object when not is_nil(object) <- Levels.get_tile_by_id(state, %{id: object_id}),
           tile when not is_nil(tile) <- Levels.get_tile(state, object, direction) do
        via_function.(runner_state, %{data | target: tile.id})
      else
        _ ->
          runner_state
      end
    end
  end
end
