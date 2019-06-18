defmodule DungeonCrawl.Repo.Migrations.AddZIndexToMapTiles do
  use Ecto.Migration

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeon.MapTile

  def change do
    alter table(:dungeon_map_tiles) do
      add :z_index, :integer
    end

    flush()

    # Update with z_index 0
    Repo.all(MapTile)
    |> Enum.each(fn(mt) -> Dungeon.update_map_tile!(mt, %{z_index: 0}) end)
  end
end
