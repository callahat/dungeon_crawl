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
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.TileTemplates

  defstruct dungeon: nil,
            levels: %{},
            tiles: %{},
            items: %{},
            tile_templates: %{},
            sounds: %{}

  def run(dungeon_id) do
    dungeon = Dungeons.get_dungeon!(dungeon_id)
              |> Repo.preload([:user, [levels: [:tiles, :spawn_locations]]])

    extract_dungeon_data(%DungeonExports{}, dungeon)
    |> sto_starting_item_slugs(dungeon)
    |> extract_level_data(dungeon.levels)
  end

  # these can be private, for now easier to work on them one at a time
  def extract_dungeon_data(export, dungeon) do
    # parse state and check starting_equipment for what items need copied over,
    # if none grab the default "gun"
    %{ export | dungeon: Dungeons.copy_dungeon_fields(dungeon) }
  end

  def extract_level_data(export, []), do: export
  def extract_level_data(export, [level | levels])  do
    {export, tile_data} = extract_tile_data(export, %{}, level.tiles)

    level_fields = Dungeons.copy_level_fields(level)
                   |> Map.put(:tile_data, tile_data)

    extract_level_data(%{ export | levels: Map.put(export.levels, level.number, level_fields)}, levels)
  end

  def extract_tile_data(export, dried_tiles, []), do: {export, dried_tiles}
  def extract_tile_data(%{tiles: tiles} = export, dried_tiles, [level_tile | level_tiles]) do
    {coords, tile_fields} = Dungeons.copy_tile_fields(level_tile)
                            |> Map.split([:row, :col, :z_index])
    tile_hash = Base.encode64(:crypto.hash(:md5, inspect(tile_fields)))

    export = sto_tile_template(export, tile_fields.tile_template_id)

    export = if Map.has_key?(tiles, tile_hash),
               do: export,
               else: %{ export | tiles: Map.put(tiles, tile_hash, tile_fields) }

    dried_tiles = Map.put(dried_tiles, {coords.row, coords.col, coords.z_index}, tile_hash)

    extract_tile_data(export, dried_tiles, level_tiles)

    # grab the tile attributes, separate except row, col, zindex from the rest
    # hash it, add or lookup to the tiles map. if its added, also see if the given tile template
    # id exists in the tile templates map (look it up and add it if not)

    # replace the tile_template_id with the temporary id for that tile template
    # compare the TT with the tile, if match use the TT hash and add the TT to the export data
    # if not a match, add the hash to the tiles map with the data.

    # last step is to go through everything and repoint the slugs to the temp slug/ids
  end

  # get the temporary tile template id, updates export if needed, returns export and the id in a tuple
  def sto_tile_template(export, nil), do: export
  def sto_tile_template(export, tile_template_id) do
    if Map.has_key?(export.tile_templates, tile_template_id) do
      export
    else
      tt = TileTemplates.get_tile_template(tile_template_id)
           |> Map.put(:temp_tt_id, "tmp_tt_id_#{map_size(export.tile_templates)}")

      %{ export | tile_templates: Map.put(export.tile_templates, tile_template_id, tt)}
    end
  end

  def sto_starting_item_slugs(export, dungeon) do
    case Regex.named_captures(~r/starting_equipment: (?<eq>[ \w\d]+)/, dungeon.state) do
      %{"eq" => equipment} ->
        String.split(equipment)
        |> Enum.reduce(export, fn slug, export -> sto_item_slug(export, slug) end)
      nil ->
        sto_item_slug(export, "gun")
    end
  end

  def sto_item_slug(export, slug) do
    if Map.has_key?(export.items, slug) do
      export
    else
      item = Equipment.get_item(slug)
             |> Map.put(:temp_item_id, "tmp_item_id_#{map_size(export.items)}")

      %{ export | items: Map.put(export.items, slug, item)}
    end
  end

#  def check_for_tile_template_slugs(export, %{script: script}) do
#    slugs = Regex.scan(~r/slug: [\w\d_]+/)
#
#    Enum.reduce(export)
#
#
#    # put, become - tile template slug
#    # equip/unequip - item
#    # sound - sound that is played
#    # dungeon also needs starting_equipment checked
#  end
end
