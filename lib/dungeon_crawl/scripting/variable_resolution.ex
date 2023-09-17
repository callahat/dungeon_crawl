defmodule DungeonCrawl.Scripting.VariableResolution do
  @moduledoc """
  Resolves variables to values.
  """

  alias DungeonCrawl.DungeonProcesses.{Levels, DungeonRegistry, DungeonProcess}
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Player.Location

  def resolve_variables(%Runner{}, []), do: []
  def resolve_variables(%Runner{} = runner_state, [variable | variables]) do
    [ resolve_variable(runner_state, variable) | resolve_variables(runner_state, variables) ]
  end
  def resolve_variables(%Runner{} = runner_state, variable_map) when is_map(variable_map) do
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
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.character
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :color}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.color
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :background_color}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.background_color
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :name}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.name
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :row}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.row
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, :col}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.col
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {:state_variable, var}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    object.state[var]
  end
  def resolve_variable(%Runner{object_id: object_id}, [:self]) do
    object_id
  end
  def resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, :id}) do
    case event_sender do
      %Location{} -> event_sender.tile_instance_id
      %{tile_id: id} ->  id
      %{id: id} ->  id
      _ -> nil
    end
  end
  def resolve_variable(runner_state, [:event_sender]) do
    resolve_variable(runner_state, {:event_sender_variable, :id})
  end
  def resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, :name}) do
    event_sender && event_sender.name
  end
  def resolve_variable(%Runner{event_sender: event_sender}, {:event_sender_variable, var}) do
    event_sender && event_sender.state[var]
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
  def resolve_variable(%Runner{state: state}, {:dungeon_instance_state_variable, var}) do
    {:ok, dungeon_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id)
    DungeonProcess.get_state_value(dungeon_process, var)
  end
  def resolve_variable(%Runner{}, {:random, range}) do
    Enum.random(range)
  end
  def resolve_variable(%Runner{object_id: object_id, state: state} = runner_state, {target, :distance}) do
    case resolve_variable(runner_state, target) do
      target_id when is_integer(target_id) ->
        object = Levels.get_tile_by_id(state, %{id: object_id})
        target = Levels.get_tile_by_id(state, %{id: target_id})
        Direction.distance(object, target)

      _ ->
        nil
    end
  end
  def resolve_variable(%Runner{object_id: object_id, state: state}, {:any_player, :is_facing}) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    case object.state[:facing] do
      nil ->    false
      "idle" -> false
      direction ->
        state.player_locations
        |> Map.to_list()
        |> Enum.map(fn({tile_id, _}) ->
             player_tile = Levels.get_tile_by_id(state, %{id: tile_id})
             Direction.orthogonal_direction(object, player_tile)
           end)
        |> Enum.member?([direction])
    end
  end
  def resolve_variable(%Runner{object_id: object_id, state: state} = runner_state, {target, :is_facing}) do
    case resolve_variable(runner_state, target) do
      tile_id when is_integer(tile_id) ->
        object = Levels.get_tile_by_id(state, %{id: object_id})
        player_tile = Levels.get_tile_by_id(state, %{id: tile_id})
        ! is_nil(object.state[:facing]) &&
          Direction.orthogonal_direction(object, player_tile) == [object.state[:facing]]

      _ ->
        false
    end
  end
  def resolve_variable(%Runner{} = runner_state, {{:state_variable, state_var}, var}) do
    direction = resolve_variable(runner_state, {:state_variable, state_var})
    resolve_variable(runner_state, {{:direction, direction}, var})
  end
  def resolve_variable(%Runner{state: state, object_id: object_id}, {{:direction, direction}, var}) do
    base = Levels.get_tile_by_id(state, %{id: object_id})
    object = if Direction.valid_orthogonal_change?(direction) do
               Levels.get_tile(state, base, Direction.change_direction(base.state[:facing], direction))
             else
               Levels.get_tile(state, base, direction)
             end
    object && resolve_variable(%Runner{state: state, object_id: object.id}, {:state_variable, var})
  end
  def resolve_variable(%Runner{}, literal) do
    literal
  end
end
