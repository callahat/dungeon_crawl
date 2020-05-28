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
require Logger
  def resolve_variable_map(%{} = runner_state, variable_map) when is_map(variable_map) do
Logger.info inspect variable_map
    variable_map
    |> Map.to_list()
    |> Enum.map(fn {key, val} -> Logger.info(inspect(val)); {key, resolve_variable(runner_state, val)} end)
    |> Enum.into(%{})
  end
  def resolve_variable(%{} = runner_state, {type, var, concat}) do
    resolved_variable = resolve_variable(runner_state, {type, var})
    if is_binary(resolved_variable) do
      resolved_variable <> concat
    else
      resolved_variable
    end
  end
  def resolve_variable(%{}, {:state_variable, :character}) do
Logger.info "Splach"
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
  def resolve_variable(%{}, {:state_variable, _var}) do
    "."
  end
  def resolve_variable(%{}, {:event_sender_variable, _var}) do
    "from sender"
  end
  def resolve_variable(%{}, {:instance_state_variable, _var}) do
    "from the instance"
  end
  def resolve_variable(%{}, {{:direction, _direction}, _var}) do
    "from a direction"
  end
  def resolve_variable(%{}, literal) do
    literal
  end
end
