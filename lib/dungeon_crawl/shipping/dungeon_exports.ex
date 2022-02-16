defmodule DungeonCrawl.Shipping.DungeonExports do
  @moduledoc """
  The Dungeon Exporter module. Its goal is to take a single dungeon and generate a portable JSON file
  that replaces ids, foreign keys, and slugs with identifiers that reference other items in the export
  file, so the dungeon, its levels, tiles, and all dependent sounds, items, tile templates and other
  assets can be found or created in the destination application. Any information on previous versions
  will not be moved over.

  `line_identifier` will be set to null as this ancestor ID may not exist (but can be manually set later)
  """

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping.DungeonExports

  defstruct dungeon: nil,
            levels: %{},
            tiles: %{},
            tile_tempates: %{},
            sounds: %{}

  def run(dungeon_id) do
    dungeon = Dungeons.get_dungeon!(dungeon_id)
              |> Repo.preload([:user, [levels: [:tiles, :spawn_locations]]])

    extract_dungeon_data(%DungeonExports{}, dungeon)
  end

  # these can be private, for now easier to work on them one at a time
  def extract_dungeon_data(export, dungeon) do
    %{ export | dungeon: Dungeons.copy_dungeon_fields(dungeon) }
  end

  def extract_level_data(export, []), do: export
  def extract_level_data(export, [level | levels])  do
    level_fields = Dungeons.copy_level_fields(level)

  end

  #
  # :crypto.hash(:md5, inspect(tile_copyable_attrs)) |> Base.encode64
  def extract_tile_data(export, []), do: export
  def extract_tile_data(export, [tile | tiles]) do
    # grab the tile attributes, separate except row, col, zindex from the rest
    # hash it, add or lookup to the tiles map. if its added, also see if the given tile template
    # id exists in the tile templates map (look it up and add it if not)
    # replace the tile_template_id with the temporary id for that tile template
    # compare the TT with the tile, if match use the TT hash and add the TT to the export data
    # if not a match, add the hash to the tiles map with the data.
  end
end
