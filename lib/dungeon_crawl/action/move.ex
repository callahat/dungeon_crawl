defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile

  # todo: rename this
  def go(%MapTile{} = entity_map_tile, %MapTile{} = destination, %Instances{} = state) do
    cond do
      destination.parsed_state[:blocking] ->
        {:invalid}

      true ->
        top_tile = Map.take(destination, [:map_instance_id, :row, :col, :z_index])
        {new_location, state} = Instances.update_map_tile(state, entity_map_tile, Map.put(top_tile, :z_index, top_tile.z_index+1))
        old_location_top_tile = Instances.get_map_tile(state, Map.take(entity_map_tile, [:row, :col]))
        old_location = if old_location_top_tile, do: old_location_top_tile, else: Map.merge(%MapTile{}, Map.take(entity_map_tile, [:row, :col]))
        {:ok, %{new_location: new_location, old_location: old_location}, state}

    end
  end
  def go(_, _, _), do: {:invalid}

  def can_move(nil), do: false
  def can_move(destination) do
    !destination.parsed_state[:blocking]
  end
end
