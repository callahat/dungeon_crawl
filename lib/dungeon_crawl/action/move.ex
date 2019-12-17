defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.TileState.Parser

  # todo: rename this
  def go(%MapTile{} = entity_map_tile, %MapTile{} = destination) do
    if _valid_move(destination) do
      top_tile = Map.take(destination, [:map_instance_id, :row, :col, :z_index])
      new_location = Instances.update_map_tile(entity_map_tile, Map.put(top_tile, :z_index, top_tile.z_index+1))
      old_location_top_tile = Instances.get_map_tile(Map.take(entity_map_tile, [:map_instance_id, :row, :col]))
      old_location = if old_location_top_tile, do: old_location_top_tile, else: Map.merge(%MapTile{}, Map.take(entity_map_tile, [:row, :col]))
      {:ok, %{new_location: new_location, old_location: old_location}}
    else
      # might change this later to have more info, ie, bumped wall, cant pass through solid rock, etc
      {:invalid}
    end
  end
  def go(_, _), do: {:invalid}

  defp _valid_move(destination) do
    {:ok, state} = Parser.parse(destination.state)
    !state[:blocking]
  end
end
