defmodule DungeonCrawl.Action.Door do
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.EventResponder.Parser
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  def open(%MapTile{} = door_location) do
    {:ok, responders} = Parser.parse(Repo.preload(door_location,:tile_template).tile_template.responders)
    _try_door door_location, responders[:open]
  end

  def close(%MapTile{} = door_location) do
    {:ok, responders} = Parser.parse(Repo.preload(door_location,:tile_template).tile_template.responders)

    _try_door door_location, responders[:close]
  end

  defp _try_door(door_location, response) do
    case response do
      {:ok, %{replace: [new_id]}} ->
        new_tile_template = TileTemplates.get_tile_template(new_id)
        door = Dungeon.update_map_tile!(door_location, %{tile_template_id: new_id})

        {:ok, %{door_location: %{row: door.row, col: door.col, tile_template: new_tile_template}}}
      _ ->
        {:invalid}
    end
  end
end
