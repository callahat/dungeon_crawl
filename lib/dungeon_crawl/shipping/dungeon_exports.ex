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

  use DungeonCrawl.Shipping.SlugMatching

  @derive Jason.Encoder
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
    |> check_tile_templates_for_stoable_slugs()
    |> repoint_ttids_and_slugs(:tiles)
    |> repoint_ttids_and_slugs(:items)
    |> repoint_ttids_and_slugs(:tile_templates)
    |> recalculate_tile_hashes()
    |> repoint_dungeon_item_slugs()
    |> switch_keys(:sounds, :temp_sound_id)
    |> switch_keys(:items, :temp_item_id)
    |> switch_keys(:tile_templates, :temp_tt_id)
  end

  # these can be private, for now easier to work on them one at a time
  def extract_dungeon_data(export, dungeon) do
    # parse state and check starting_equipment for what items need copied over,
    # if none grab the default "gun"
    spawn_locations = Enum.map(dungeon.spawn_locations, fn sl -> [sl.level.number, sl.row, sl.col] end)
    dungeon = Dungeons.copy_dungeon_fields(dungeon)
              |> Map.delete(:user_id)
              |> Map.put(:user_name, dungeon.user && dungeon.user.name || "(unknown)")
    %{ export | dungeon: dungeon, spawn_locations: spawn_locations }
  end

  def extract_level_and_tile_data(export, []), do: export
  def extract_level_and_tile_data(export, [level | levels])  do
    {export, tile_data} = extract_tile_data(export, %{}, level.tiles)

    level_fields = Dungeons.copy_level_fields(level)
                   |> Map.put(:tile_data, tile_data)

    extract_level_and_tile_data(%{ export | levels: Map.put(export.levels, level.number, level_fields)}, levels)
  end

  def extract_tile_data(export, dried_tiles, []) do
    {export, Enum.map(dried_tiles, fn {coords, hash} -> [hash | Tuple.to_list(coords)] end)}
  end
  def extract_tile_data(%{tiles: tiles} = export, dried_tiles, [level_tile | level_tiles]) do
    {coords, tile_fields} = Dungeons.copy_tile_fields(level_tile)
                            |> Map.split([:row, :col, :z_index])
    tile_hash = Base.encode64(:crypto.hash(:sha, inspect(tile_fields)))

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

  def check_tile_templates_for_stoable_slugs(export) do
    export.tile_templates
    |> Enum.reduce(export, fn {_, tile_template}, export ->
      check_for_tile_template_slugs(export, tile_template)
      |> check_for_script_items(tile_template)
      |> check_for_script_sounds(tile_template)
    end)
  end

  # get the temporary tile template id, updates export if needed, returns export
  def sto_tile_template(export, nil), do: export
  def sto_tile_template(export, %TileTemplate{} = tile_template) do
    if Map.has_key?(export.tile_templates, tile_template.id) do
      export
    else
      tt = TileTemplates.copy_fields(tile_template)
           |> Map.put(:temp_tt_id, "tmp_tt_id_#{map_size(export.tile_templates)}")

      %{ export | tile_templates: Map.put(export.tile_templates, tile_template.id, tt)}
    end
  end
  def sto_tile_template(export, slug) when is_binary(slug) do
    sto_tile_template(export, TileTemplates.get_tile_template_by_slug!(slug))
  end
  def sto_tile_template(export, tile_template_id) do
    sto_tile_template(export, TileTemplates.get_tile_template!(tile_template_id))
  end

  def sto_starting_item_slugs(export, dungeon) do
    case Regex.named_captures(@starting_equipment_slugs, dungeon.state || "") do
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
      item = Equipment.get_item!(slug)
             |> Equipment.copy_fields()
             |> Map.put(:temp_item_id, "tmp_item_id_#{map_size(export.items)}")

      export = check_for_tile_template_slugs(export, item)
               |> check_for_script_items(item)
               |> check_for_script_sounds(item)

      %{ export | items: Map.put(export.items, slug, item)}
    end
  end

  def sto_sound_slug(export, slug) do
    if Map.has_key?(export.sounds, slug) do
      export
    else
      sound = Sound.get_effect_by_slug!(slug)
              |> Sound.copy_fields()
              |> Map.put(:temp_sound_id, "tmp_sound_id_#{map_size(export.sounds)}")

      %{ export | sounds: Map.put(export.sounds, slug, sound)}
    end
  end

  def check_for_tile_template_slugs(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_tt_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_tile_template(export, slug)
    end)
  end

  def check_for_script_items(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_item_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_item_slug(export, slug)
    end)
  end

  def check_for_script_sounds(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_sound_slug, script)

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_sound_slug(export, slug)
    end)
  end

  def repoint_ttids_and_slugs(export, asset_key) do
    assets = Enum.map(Map.get(export, asset_key), fn {th, tile} ->
              {
                th,
                repoint_tile_template_id(tile, export)
                |> repoint_script_slugs(export, :tile_templates, :temp_tt_id, @script_tt_slug)
                |> repoint_script_slugs(export, :items, :temp_item_id, @script_item_slug)
                |> repoint_script_slugs(export, :sounds, :temp_sound_id, @script_sound_slug)
              }
            end)
            |> Enum.into(%{})

    %{ export | asset_key => assets }
  end

  def repoint_tile_template_id(%{tile_template_id: tile_template_id} = asset, export) do
    template = Map.get(export.tile_templates, tile_template_id, %{temp_tt_id: nil})
    Map.put(asset, :tile_template_id, template.temp_tt_id)
  end

  def repoint_tile_template_id(asset, _export), do: asset

  def repoint_script_slugs(asset, export, slug_type, temp_id_type, slug_pattern) do
    slug_kwargs = Regex.scan(slug_pattern, asset.script || "")

    Enum.reduce(slug_kwargs, asset, fn [slug_kwarg], asset ->
      [left_side, slug] = String.split(slug_kwarg)

      case Enum.find(Map.fetch!(export, slug_type), fn {_, i} -> i.slug == slug end) do
        {_, %{^temp_id_type => temp_slug_or_id}} ->
          Map.put(asset, :script, String.replace(asset.script, slug_kwarg, "#{left_side} #{temp_slug_or_id}"))
        _ ->
          # other errors should happen before this one that will halt processing, but just in case,
          # this will be more informative that a assignment mismatch
          raise "#{slug_type} - #{slug} - not found"
      end
    end)
  end

  def repoint_dungeon_item_slugs(%{dungeon: dungeon} = export) do
    case Regex.named_captures(@starting_equipment_slugs, dungeon.state || "") do
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

  def recalculate_tile_hashes(%{levels: levels, tiles: tiles} = export) do
    old_to_new_hash = Enum.map(tiles, fn {old_hash, tile_fields} ->
                        {old_hash, Base.encode64(:crypto.hash(:sha, inspect(tile_fields)))}
                      end)
                      |> Enum.into(%{})
    tiles = Enum.map(tiles, fn {old_hash, tile_fields} ->
              { Map.get(old_to_new_hash, old_hash), tile_fields }
            end)
            |> Enum.into(%{})
    levels = Enum.map(levels, fn {number, %{tile_data: tile_data} = level_fields} ->
               tile_data = Enum.map(tile_data, fn [old_hash | coords] ->
                             [ Map.get(old_to_new_hash, old_hash) | coords ]
                           end)
               {number, %{level_fields | tile_data: tile_data}}
             end)
             |> Enum.into(%{})

    %{ export | levels: levels, tiles: tiles }
  end

  def switch_keys(export, asset_key, temp_id_key) do
    assets = Map.get(export, asset_key)
             |> Enum.map(fn {_slug_or_id, asset} -> {Map.get(asset, temp_id_key), asset} end)
             |> Enum.into(%{})
    %{ export | asset_key => assets }
  end
end
