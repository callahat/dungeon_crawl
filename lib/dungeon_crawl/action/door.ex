defmodule DungeonCrawl.Action.Door do
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.EventResponder.Parser
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates

  def open(%MapTile{} = door_location) do
    script = door_location.script

    # TODO: actually implement a thing to parse & run scripts
    case Regex.named_captures(~r/:OPEN\n#BECOME TTID:(?<id>\d+)/, script) do
      %{"id" => id} -> _try_door(door_location, {:ok, %{replace: [id]}})
      _             -> _try_door(door_location, :nope)
    end
  end

  def close(%MapTile{} = door_location) do
    script = door_location.script

    case Regex.named_captures(~r/:CLOSE\n#BECOME TTID:(?<id>\d+)/, script) do
      %{"id" => id} -> _try_door(door_location, {:ok, %{replace: [id]}})
      _             -> _try_door(door_location, :nope)
    end
  end

  defp _try_door(door_location, response) do
    case response do
      {:ok, %{replace: [new_id]}} ->
        new_tile_template = TileTemplates.get_tile_template(new_id)
        door = Dungeon.update_map_tile!(door_location, %{tile_template_id: new_id, character: new_tile_template.character, state: new_tile_template.state, script: new_tile_template.script})

        {:ok, %{door_location: %{row: door.row, col: door.col, map_tile: door}}}
      _ ->
        {:invalid}
    end
  end
end
