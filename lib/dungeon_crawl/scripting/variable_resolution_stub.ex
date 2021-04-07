defmodule DungeonCrawl.Scripting.VariableResolutionStub do
  @moduledoc """
  Resolves variables to values for purposes of using ProgramValidator.
  Since these variables won't be known until the script is running in a dungeon
  instance, valid values will be returned so that the ProgramValidator can pass.
  Bad values at runtime are to be handled elsewhere and hopefully just ignored.
  This will at least ensure that only valid variables have been given.
  The requirement of a Runner struct has been relaxed here, but the actual Command module
  will use a Runner struct as the first param.
  """

  def resolve_variable_map(%{} = runner_state, variable_map) when is_map(variable_map) do
    variable_map
    |> Map.to_list()
    |> Enum.map(fn {key, val} -> resolve_keyed_variable(runner_state, key, val) end)
    |> Enum.into(%{})
  end
  def resolve_keyed_variable(%{} = runner_state, :character, val) do
    {:character, String.at("#{resolve_variable(runner_state, val)}", 0)}
  end
  def resolve_keyed_variable(%{}, :color, val) do
    {:color, if(is_binary(val), do: val, else: "green")}
  end
  def resolve_keyed_variable(%{}, :background_color, val) do
    {:background_color, if(is_binary(val), do: val, else: "#FFF")}
  end
  def resolve_keyed_variable(%{} = runner_state, key, val) do
    {key, resolve_variable(runner_state, val)}
  end
  def resolve_variable(%{} = runner_state, {type, var, concat}) do
    resolved_variable = resolve_variable(runner_state, {type, var})
    if is_binary(resolved_variable) do
      resolved_variable <> concat
    else
      resolved_variable
    end
  end
  def resolve_variable(%{}, {:state_variable, :id}) do
    12345
  end
  def resolve_variable(%{}, {:state_variable, :character}) do
    "X"
  end
  def resolve_variable(%{}, {:state_variable, :color}) do
    "red"
  end
  def resolve_variable(%{}, {:state_variable, :background_color}) do
    "white"
  end
  def resolve_variable(%{}, {:state_variable, :name}) do
    "Test Stub"
  end
  def resolve_variable(%{}, {:state_variable, :row}) do
    2
  end
  def resolve_variable(%{}, {:state_variable, :col}) do
    4
  end
  def resolve_variable(%{}, {:state_variable, :slug}) do
    :stubbed_slug
  end
  def resolve_variable(%{}, {:state_variable, _var}) do
    "."
  end
  def resolve_variable(%{}, {:event_sender_variable, :id}) do
    223344
  end
  def resolve_variable(%{}, {:event_sender_variable, _var}) do
    "from sender"
  end
  def resolve_variable(%{}, {:instance_state_variable, :north_edge}) do
    0
  end
  def resolve_variable(%{}, {:instance_state_variable, :west_edge}) do
    0
  end
  def resolve_variable(%{}, {:instance_state_variable, :east_edge}) do
    29
  end
  def resolve_variable(%{}, {:instance_state_variable, :south_edge}) do
    19
  end
  def resolve_variable(%{}, {:instance_state_variable, _var}) do
    "from the instance"
  end
  def resolve_variable(%{}, {:map_set_instance_state_variable, _var}) do
    999
  end
  def resolve_variable(%{}, {:random, _var}) do
    7 # is a fine random number
  end
  def resolve_variable(%{}, {_target, :distance}) do
    3.14
  end
  def resolve_variable(%{}, {:any_player, :is_facing}) do
    true
  end
  def resolve_variable(%{}, {id, :is_facing}) when is_integer(id) do
    false
  end
  def resolve_variable(%{}, {{:direction, _direction}, _var}) do
    "from a direction"
  end
  def resolve_variable(%{}, literal) do
    literal
  end
end
