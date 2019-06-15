defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.EventResponder.Parser

  alias DungeonCrawl.Repo

  # todo: rename this
  def go(entity_map_tile, destination) do
    if _valid_move(destination) do
      top_tile = Map.take(destination, [:dungeon_id, :row, :col, :z_index])
      {:ok, new_location} = Dungeon.update_map_tile(entity_map_tile, Map.put(top_tile, :z_index, top_tile.z_index+1))
      old_location = Dungeon.get_map_tile(Map.take(entity_map_tile, [:dungeon_id, :row, :col]))

      {:ok, %{new_location: new_location, old_location: old_location}}
    else
      # might change this later to have more info, ie, bumped wall, cant pass through solid rock, etc
      {:invalid}
    end
  end

  defp _valid_move(destination) do
    {:ok, responders} = Parser.parse(Repo.preload(destination,:tile_template).tile_template.responders)
    case responders[:move] do
      {:ok} -> true
      _     -> false
    end
  end
end
