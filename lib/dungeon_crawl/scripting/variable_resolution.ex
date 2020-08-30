defmodule DungeonCrawl.Scripting.VariableResolution do
  @moduledoc """
  Resolves variables to values.
  """

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Runner

  def resolve_variable_map(%Runner{} = runner_state, variable_map) when is_map(variable_map) do
    variable_map
    |> Map.to_list()
    |> Enum.map(fn {key, val} -> resolve_keyed_variable(runner_state, key, val) end)
    |> Enum.into(%{})
  end
  def resolve_keyed_variable(%Runner{} = runner_state, :character, val) do
    {:character, String.at("#{resolve_variable(runner_state, val)}", 0)}
  end
  def resolve_keyed_variable(%Runner{} = runner_state, key, val) do
    {key, resolve_variable(runner_state, val)}
  end
  def resolve_variable(%Runner{} = runner_state, {type, var, concat}) do
    resolved_variable = resolve_variable(runner_state, {type, var})
    if is_binary(resolved_variable) do
      resolved_variable <> concat
    else
      resolved_variable
    end
  end
  def resolve_variable(%Runner{state: _state, object_id: object_id}, {:state_variable, :id}) do
    object_id
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :character}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.character
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
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :row}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.row
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :col}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.col
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, var}) do
    object = Instances.get_map_tile_by_id(state, %{id: object_id})
    object.parsed_state[var]
  end
  def resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, var}) do
    event_sender && event_sender.parsed_state[var]
  end
  def resolve_variable(%Runner{}, {:instance_state_variable, :north_edge}) do
    0
  end
  def resolve_variable(%Runner{}, {:instance_state_variable, :west_edge}) do
    0
  end
  def resolve_variable(%Runner{state: state}, {:instance_state_variable, :east_edge}) do
    state.state_values[:cols] - 1
  end
  def resolve_variable(%Runner{state: state}, {:instance_state_variable, :south_edge}) do
    state.state_values[:rows] - 1
  end
  def resolve_variable(%Runner{state: state}, {:instance_state_variable, var}) do
    state.state_values[var]
  end
  def resolve_variable(%Runner{} = runner_state, {{:state_variable, state_var}, var}) do
    direction = resolve_variable(runner_state, {:state_variable, state_var})
    resolve_variable(runner_state, {{:direction, direction}, var})
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {{:direction, direction}, var}) do
    base = Instances.get_map_tile_by_id(state, %{id: object_id})
    object = if Direction.valid_orthogonal_change?(direction) do
               Instances.get_map_tile(state, base, Direction.change_direction(base.parsed_state[:facing], direction))
             else
               Instances.get_map_tile(state, base, direction)
             end
    object && resolve_variable(%Runner{state: state, object_id: object.id}, {:state_variable, var})
  end
  def resolve_variable(%Runner{}, literal) do
    literal
  end
end
