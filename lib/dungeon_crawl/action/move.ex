defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.{Dungeon,Player}
  alias DungeonCrawl.EventResponder.Parser

  alias DungeonCrawl.Repo

  # todo: rename this
  def go(entity_location, destination, entity_module \\ Player) do
    if _valid_move(destination) do
      {:ok, new_location} = entity_module.update_location(entity_location, Map.take(destination, [:dungeon_id, :row, :col]))
      old_location = Dungeon.get_map_tile(Map.take(entity_location, [:dungeon_id, :row, :col]))

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
