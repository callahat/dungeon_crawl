defmodule DungeonCrawl.Scripting.Command do
  @moduledoc """
  The various scripting commands available to a program.
  """

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Maths
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
      :if           -> :if
      :move         -> :move
      :noop         -> :noop
      :text         -> :text

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

    iex> Command.become(%{program: program, object: object, params: [%{character: $}]})
    %{program: %{program | broadcasts: [ ["tile_changes", %{tiles: [%{row: 1, col: 1, rendering: "<div>$</div>"}]}] ]},
      object: updated_object }
  """
  def become(%{program: program, object: object, params: [{:ttid, ttid}]}) do
    new_attrs = Map.take(TileTemplates.get_tile_template!(ttid), [:character, :color, :background_color, :state, :script])
    _become(%{program: program, object: object}, Map.put(new_attrs, :tile_template_id, ttid))
  end
  def become(%{program: program, object: object, params: [params]}) do
    new_attrs = Map.take(params, [:character, :color, :background_color, :state, :script, :tile_template_id])
    _become(%{program: program, object: object}, new_attrs)
  end
  def _become(%{program: program, object: object}, new_attrs) do
IO.puts "IN BECOME"
IO.puts inspect object
IO.puts inspect new_attrs
    object = Instances.update_map_tile(
               object,
               new_attrs)
IO.puts "INSTANCE UPDATED"
    message = ["tile_changes",
               %{tiles: [
                   Map.put(Map.take(object, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(object))
               ]}]

    if Map.has_key?(new_attrs, :script) do
      {:ok, new_program} = Scripting.Parser.parse(new_attrs.script)
      %{ program: %{new_program | broadcasts: [message | program.broadcasts], responses: program.responses, status: :idle },
         object: object}
    else
      %{ program: %{program | broadcasts: [message | program.broadcasts] },
         object: object}
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

    iex> Command.change_state(%{program: program, object: %{state: "counter: 1"}, params: [:counter, "+=", 3]})
    %{program: program,
      object: %{ object | state: "counter: 4"} }
  """
  def change_state(%{program: program, object: object, params: params}) do
    {:ok, state} = TileState.Parser.parse(object.state)
    [var, op, value] = params

    state = Map.put(state, var, Maths.calc(state[var] || 0, op, value)) |> TileState.Parser.stringify

    %{program: program,
      object: Instances.update_map_tile(object, %{state: state})}
  end

  @doc """
  Kills the script for the object. Returns a dead program, and deletes the script from the object (map_tile instance)

  ## Examples

    iex> Command.die(%{program: program, object: %{script: "..."}}
    %{program: %{program | pc: -1, status: :dead},
      object: %{ object | script: ""} }
  """
  def die(%{program: program, object: object}) do
    object = Instances.update_map_tile(object, %{script: ""})
    %{program: %{program | status: :dead, pc: -1},
      object: object}
  end

  @doc """
  Changes the program state to idle and sets the pc to -1. This indicates that the program is still alive,
  but awaiting a message to respond to (ie, a TOUCH event)

  ## Examples

    iex> Command.halt(%{program: program, object: object})
    %{program: %{program | pc: -1, status: :idle},
      object: object }
  """
  def halt(%{program: program, object: object}) do
    %{ program: %{program | status: :idle, pc: -1},
       object: object}
  end

  @doc """
  Conditionally jump to a label. Program counter (pc) will be set to the location of the first active label
  if the expression evaluates to true. Otherwise the pc will not be changed. If there is no active matching label,
  the pc will also be unchanged.
  """
  def if(%{program: program, object: object, params: params}) do
    {:ok, state} = DungeonCrawl.TileState.Parser.parse(object.state)
    [[neg, _command, var, op, value], label] = params

    # first active matching label
    with labels when not is_nil(labels) <- program.labels[label],
         [[line_number, _]] <- labels |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1),
         true <- Maths.check(neg, state[var], op, value) do
      %{ program: %{program | pc: line_number}, object: object}
    else
      _ -> %{program: program, object: object}
    end
  end

  @doc """
  Moves the associated map tile/object based in the direction given by the first parameter.
  If the second parameter is `true` then the command will retry until the object is able
  to complete the move (unless the program also responds to THUD). When `false` (or not present)
  it will attempt once, and then move on with the next instruction.

  If the movement is invalid, the `pc` will be set to the location of the `THUD` label if an active one exists.

  Valid directions:
  north - up
  south - down
  east  - right
  west  - left
  idle  - no movement

  ## Examples

    iex> Command.move(%{program: %Program{}, object: object, params: ["n", true]})
    %{program: %{ program | status: :wait, wait_cycles: 5 }, object: %{object | row: object.row - 1}}
  """
  def move(%{program: program, object: object, params: ["idle", _]}) do
    %{ program: %{program | status: :wait, wait_cycles: 5 },
       object: object}
  end
  def move(%{program: program, object: object, params: [direction]}) do
    move(%{program: program, object: object, params: [direction, false]})
  end
  def move(%{program: program, object: object, params: [direction, retry_until_successful]}) do
    destination = Instances.get_map_tile(object, direction)

    case Move.go(object, destination) do
      {:ok, %{new_location: new_location, old_location: old}} ->

        message = ["tile_changes",
               %{tiles: [
                     Map.put(Map.take(new_location, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(new_location)),
                     Map.put(Map.take(old, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(old))
               ]}]

        %{ program: %{program | broadcasts: [message | program.broadcasts], status: :wait, wait_cycles: 5 },
           object: new_location}
      {:invalid} ->
        with labels when not is_nil(labels) <- program.labels["THUD"],
             [[line_number, _]] <- labels |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1) do
          %{ program: %{program | pc: line_number}, object: object}
        else
          _ ->
            if retry_until_successful do
              %{program: %{program | pc: program.pc - 1, status: :wait, wait_cycles: 5}, object: object}
            else
              %{program: %{program | status: :wait, wait_cycles: 5}, object: object}
            end
        end
    end
  end

  @doc """
  Non operation. Returns unaltered parameters.

  ## Examples

    iex> Command.noop(%{program: %Program{}, object: object})
    %{program: %Program{}, object: object}
  """
  def noop(params) do
    params
  end

  @doc """
  Adds text to the responses for showing to a player in particular (ie, one who TOUCHed the object).

  ## Examples

    iex> Command.text(%{program: program, object: object, params: ["Door opened"]})
    %{program: %{program | responses: ["Door opened"]},
      object: object }
  """
  def text(%{program: program, object: object, params: params}) do
    if params != [""] do
      # TODO: probably allow this to be refined by whomever the message is for
      message = Enum.map(params, fn(param) -> String.trim(param) end) |> Enum.join("\n")
      %{program: %{program | responses: [ message | program.responses] },
        object: object}
    else
      %{program: program, object: object}
    end
  end

end
