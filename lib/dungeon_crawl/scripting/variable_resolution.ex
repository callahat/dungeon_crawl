defmodule DungeonCrawl.Scripting.VariableResolution do
  @moduledoc """
  Resolves variables to values.
  """

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Runner

  def resolve_variable_map(%Runner{} = runner_state, variable_map) when is_map(variable_map) do
    variable_map
    |> Map.to_list()
    |> Enum.map(fn {key, val} -> {key, resolve_variable(runner_state, val)} end)
    |> Enum.into(%{})
  end
  def resolve_variable(%Runner{} = runner_state, {type, var, concat}) do
    resolved_variable = resolve_variable(runner_state, {type, var})
    if is_binary(resolved_variable) do
      resolved_variable <> concat
    else
      resolved_variable
    end
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :color}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.color
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :background_color}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.background_color
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :name}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.name
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, var}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.parsed_state[var]
  end
  def resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, var}) do
    event_sender && event_sender.parsed_state[var]
  end
  def resolve_variable(%Runner{state: state}, {:instance_state_variable, var}) do
    state.state_values[var]
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {{:direction, direction}, var}) do
    base = Instances.get_map_tile_by_id(state, %{id: object_id})
    object = Instances.get_map_tile(state, base, direction)
    object && object.parsed_state[var]
  end
  def resolve_variable(%Runner{}, literal) do
    literal
  end
end
