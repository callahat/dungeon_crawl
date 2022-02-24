defmodule DungeonCrawl.Shipping.DungeonExports do
  @moduledoc """
  The Dungeon Exporter module. Its goal is to take a single dungeon and generate a struct
  that replaces ids, foreign keys, and slugs with identifiers that reference other items in the export
  file, so the dungeon, its levels, tiles, and all dependent sounds, items, tile templates and other
  assets can be found or created in the destination application. Any information on previous versions
  will not be moved over.

  `line_identifier` will be set to null as this ancestor ID may not exist (but can be manually set later)
  """

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Sound

  @starting_equipment_slugs ~r/starting_equipment: (?<eq>[ \w\d]+)/
  @tile_script_tt_slug ~r/slug: [\w\d_]+/i
  @tile_script_item_slug ~r/#(?:un)?equip [\w\d_]+/i
  @tile_script_sound_slug ~r/#sound [\w\d_]+/i

  defstruct dungeon: nil,
            levels: %{},
            tiles: %{},
            items: %{},
            tile_templates: %{},
            sounds: %{},
            spawn_locations: []

  def run(dungeon_id) do
    dungeon = Dungeons.get_dungeon!(dungeon_id)
              |> Repo.preload([:user, [levels: :tiles, spawn_locations: :level]])

    extract_dungeon_data(%DungeonExports{}, dungeon)
    |> sto_starting_item_slugs(dungeon)
    |> extract_level_and_tile_data(dungeon.levels)
    |> repoint_tiles_ttids_and_slugs()
    |> repoint_dungeon_item_slugs()
  end

  # these can be private, for now easier to work on them one at a time
  def extract_dungeon_data(export, dungeon) do
    # parse state and check starting_equipment for what items need copied over,
    # if none grab the default "gun"
    spawn_locations = Enum.map(dungeon.spawn_locations, fn sl -> {sl.level.number, sl.row, sl.col} end)
    dungeon = Dungeons.copy_dungeon_fields(dungeon)
    %{ export | dungeon: dungeon, spawn_locations: spawn_locations }
  end

  def extract_level_and_tile_data(export, []), do: export
  def extract_level_and_tile_data(export, [level | levels])  do
    {export, tile_data} = extract_tile_data(export, %{}, level.tiles)

    level_fields = Dungeons.copy_level_fields(level)
                   |> Map.put(:tile_data, tile_data)

    extract_level_and_tile_data(%{ export | levels: Map.put(export.levels, level.number, level_fields)}, levels)
  end

  def extract_tile_data(export, dried_tiles, []), do: {export, dried_tiles}
  def extract_tile_data(%{tiles: tiles} = export, dried_tiles, [level_tile | level_tiles]) do
    {coords, tile_fields} = Dungeons.copy_tile_fields(level_tile)
                            |> Map.split([:row, :col, :z_index])
    tile_hash = Base.encode64(:crypto.hash(:md5, inspect(tile_fields)))

    export = sto_tile_template(export, tile_fields.tile_template_id)

    export = if Map.has_key?(tiles, tile_hash) do
               export
             else
               export = check_for_tile_template_slugs(export, tile_fields)
                        |> check_for_script_items(tile_fields)
                        |> check_for_script_sounds(tile_fields)
               %{ export | tiles: Map.put(tiles, tile_hash, tile_fields) }
             end

    dried_tiles = Map.put(dried_tiles, {coords.row, coords.col, coords.z_index}, tile_hash)

    extract_tile_data(export, dried_tiles, level_tiles)
  end

  # get the temporary tile template id, updates export if needed, returns export and the id in a tuple
  def sto_tile_template(export, nil), do: export
  def sto_tile_template(export, %TileTemplate{} = tile_template) do
    if Map.has_key?(export.tile_templates, tile_template.id) do
      export
    else
      tt = Map.put(tile_template, :temp_tt_id, "tmp_tt_id_#{map_size(export.tile_templates)}")

      %{ export | tile_templates: Map.put(export.tile_templates, tile_template.id, tt)}
    end
  end
  def sto_tile_template(export, slug) when is_binary(slug) do
    sto_tile_template(export, TileTemplates.get_tile_template_by_slug(slug))
  end
  def sto_tile_template(export, tile_template_id) do
    sto_tile_template(export, TileTemplates.get_tile_template(tile_template_id))
  end

  def sto_starting_item_slugs(export, dungeon) do
    case Regex.named_captures(@starting_equipment_slugs, dungeon.state) do
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

  def sto_sound_slug(export, slug) do
    if Map.has_key?(export.sounds, slug) do
      export
    else
      sound = Sound.get_effect_by_slug(slug)
              |> Map.put(:temp_sound_id, "tmp_sound_id_#{map_size(export.sounds)}")

      %{ export | sounds: Map.put(export.sounds, slug, sound)}
    end
  end

  def check_for_tile_template_slugs(export, %{script: script}) do
    slug_kwargs = Regex.scan(@tile_script_tt_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_tile_template(export, slug)
    end)
  end

  def check_for_script_items(export, %{script: script}) do
    slug_kwargs = Regex.scan(@tile_script_item_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_item_slug(export, slug)
    end)
  end

  def check_for_script_sounds(export, %{script: script}) do
    slug_kwargs = Regex.scan(@tile_script_sound_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_sound_slug(export, slug)
    end)
  end

  def repoint_tiles_ttids_and_slugs(%{tiles: tiles} = export) do
    tiles = Enum.map(tiles, fn {th, tile} ->
              {
                th,
                repoint_tile_template_id(tile, export)
                |> repoint_tile_script_slugs(export, :tile_templates, :temp_tt_id, @tile_script_tt_slug)
                |> repoint_tile_script_slugs(export, :items, :temp_item_id, @tile_script_item_slug)
                |> repoint_tile_script_slugs(export, :sounds, :temp_sound_id, @tile_script_sound_slug)
              }
            end)

    %{ export | tiles: tiles }
  end

  def repoint_tile_template_id(tile, export) do
    template = Map.get(export.tile_templates, tile.tile_template_id, %{temp_tt_id: nil})
    Map.put(tile, :tile_template_id, template.temp_tt_id)
  end

  def repoint_tile_script_slugs(tile, export, slug_type, temp_id_type, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, tile.script || "")

    Enum.reduce(slug_kwargs, tile, fn [slug_kwarg], tile ->
      [left_side, slug] = String.split(slug_kwarg)
      {_, %{^temp_id_type => temp_slug_or_id}} = Enum.find(Map.fetch!(export, slug_type), fn {_, i} -> i.slug == slug end)
      Map.put(tile, :script, String.replace(tile.script, slug_kwarg, "#{left_side} #{temp_slug_or_id}"))
    end)
  end

  def repoint_dungeon_item_slugs(%{dungeon: dungeon} = export) do
    case Regex.named_captures(@starting_equipment_slugs, dungeon.state) do
      %{"eq" => equipment} ->
        starting_equipment = \
        String.split(equipment)
        |> Enum.map(fn slug -> export.items[slug].temp_item_id end)
        |> Enum.join(" ")

        dungeon = %{ dungeon | state: String.replace(dungeon.state, equipment, starting_equipment)}
        %{ export | dungeon: dungeon }
      nil ->
        export
    end
  end
end
