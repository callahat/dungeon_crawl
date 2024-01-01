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
            spawn_locations: [],
            status: "running"

  def run(dungeon_id) do
    dungeon = Dungeons.get_dungeon!(dungeon_id)
              |> Repo.preload([:user, [levels: :tiles, spawn_locations: :level]])

    extract_dungeon_data(%DungeonExports{}, dungeon)
    |> sto_starting_item_slugs(dungeon)
    |> extract_level_and_tile_data(dungeon.levels)
    |> check_tile_templates_for_stoable_slugs()
    |> add_temp_ids_for_assets()
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
  defp extract_dungeon_data(export, dungeon) do
    # parse state and check starting_equipment for what items need copied over,
    # if none grab the default "gun"
    spawn_locations = Enum.map(dungeon.spawn_locations, fn sl -> [sl.level.number, sl.row, sl.col] end)
    dungeon = Dungeons.copy_dungeon_fields(dungeon)
              |> Map.delete(:user_id)
              |> Map.put(:user_name, dungeon.user && dungeon.user.name || "(unknown)")
    %{ export | dungeon: dungeon, spawn_locations: spawn_locations }
  end

  defp extract_level_and_tile_data(export, []), do: export
  defp extract_level_and_tile_data(export, [level | levels])  do
    {export, tile_data} = extract_tile_data(export, %{}, level.tiles)

    level_fields = Dungeons.copy_level_fields(level)
                   |> Map.put(:tile_data, tile_data)

    extract_level_and_tile_data(%{ export | levels: Map.put(export.levels, level.number, level_fields)}, levels)
  end

  defp extract_tile_data(export, dried_tiles, []) do
    {export, Enum.map(dried_tiles, fn {coords, hash} -> [hash | Tuple.to_list(coords)] end)}
  end
  defp extract_tile_data(%{tiles: tiles} = export, dried_tiles, [level_tile | level_tiles]) do
    {coords, tile_fields} = Dungeons.copy_tile_fields(level_tile)
                            |> Map.split([:row, :col, :z_index])
    tile_hash = calculate_tile_hash(tile_fields)

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

  defp check_tile_templates_for_stoable_slugs(export) do
    export.tile_templates
    |> Enum.reduce(export, fn {_, tile_template}, export ->
      check_for_tile_template_slugs(export, tile_template)
      |> check_for_script_items(tile_template)
      |> check_for_script_sounds(tile_template)
    end)
  end

  # get the temporary tile template id, updates export if needed, returns export
  defp sto_tile_template(export, nil), do: export
  defp sto_tile_template(export, %TileTemplate{} = tile_template) do
    if Map.has_key?(export.tile_templates, tile_template.id) do
      export
    else
      tt = TileTemplates.copy_fields(tile_template)
           |> Map.put(:id, tile_template.id)
           |> Map.put(:previous_version_id, tile_template.previous_version_id)

      %{ export | tile_templates: Map.put(export.tile_templates, tile_template.id, tt)}
    end
  end
  defp sto_tile_template(export, slug) when is_binary(slug) do
    sto_tile_template(export, TileTemplates.get_tile_template_by_slug!(slug))
  end
  defp sto_tile_template(export, tile_template_id) do
    sto_tile_template(export, TileTemplates.get_tile_template!(tile_template_id))
  end

  defp sto_starting_item_slugs(export, dungeon) do
    case dungeon.state do
      %{"starting_equipment" => equipment} ->
        equipment
        |> Enum.reduce(export, fn slug, export -> sto_item_slug(export, slug) end)
      _ ->
        sto_item_slug(export, "gun")
    end
  end

  defp sto_item_slug(export, slug) do
    if Map.has_key?(export.items, slug) do
      export
    else
      item = Equipment.get_item!(slug)
      item = Equipment.copy_fields(item)
             |> Map.put(:id, item.id)

      %{ export | items: Map.put(export.items, slug, item)}
      |> check_for_tile_template_slugs(item)
      |> check_for_script_items(item)
      |> check_for_script_sounds(item)
    end
  end

  defp sto_sound_slug(export, slug) do
    if Map.has_key?(export.sounds, slug) do
      export
    else
      sound = Sound.get_effect_by_slug!(slug)
      sound = Sound.copy_fields(sound)
              |> Map.put(:id, sound.id)

      %{ export | sounds: Map.put(export.sounds, slug, sound)}
    end
  end

  defp check_for_tile_template_slugs(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_tt_slug, script || "")

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_tile_template(export, slug)
    end)
  end

  defp check_for_script_items(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_item_slug, script || "")

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_item_slug(export, slug)
    end)
  end

  defp check_for_script_sounds(export, %{script: script}) do
    slug_kwargs = Regex.scan(@script_sound_slug, script || "")

    Enum.reduce(slug_kwargs, export, fn [slug_kwarg], export ->
      [_, slug] = String.split(slug_kwarg)
      sto_sound_slug(export, slug)
    end)
  end

  defp add_temp_ids_for_assets(export) do
    %{sounds: sounds, items: items, tile_templates: tile_templates} = export

    sounds = sounds
             |> Enum.sort(fn({_slug_a, assert_a}, {_slug_b, asset_b}) -> assert_a.id < asset_b.id end)
             |> Enum.reduce(%{}, fn {slug, sound}, sounds ->
                  sound = Map.delete(sound, :id)
                          |> Map.put(:temp_sound_id, "tmp_sound_id_#{map_size(sounds)}")
                  Map.put(sounds, slug, sound)
                end)

    items = items
             |> Enum.sort(fn({_slug_a, assert_a}, {_slug_b, asset_b}) -> assert_a.id < asset_b.id end)
             |> Enum.reduce(%{}, fn {slug, item}, items ->
                  item = Map.delete(item, :id)
                         |> Map.put(:temp_item_id, "tmp_item_id_#{map_size(items)}")
                  Map.put(items, slug, item)
                end)

    tile_templates = tile_templates
            |> Enum.sort(fn({_slug_a, asset_a}, {_slug_b, asset_b}) ->
                 tile_template_oldest_id(asset_a) < tile_template_oldest_id(asset_b)
               end)
            |> Enum.reduce(%{}, fn {slug, tile_template}, tile_templates ->
                 tile_template = Map.delete(tile_template, :id)
                                 |> Map.delete(:previous_version_id)
                                 |> Map.put(:temp_tt_id, "tmp_tt_id_#{map_size(tile_templates)}")
                 Map.put(tile_templates, slug, tile_template)
               end)

    %{ export | sounds: sounds, items: items, tile_templates: tile_templates}
  end

  defp tile_template_oldest_id(%{previous_version_id: nil} = tile_template), do: tile_template.id
  defp tile_template_oldest_id(%{previous_version_id: tile_template_id} = _tile_template) do
    TileTemplates.get_tile_template!(tile_template_id)
    |> tile_template_oldest_id()
  end

  defp repoint_ttids_and_slugs(export, asset_key) do
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

  defp repoint_tile_template_id(%{tile_template_id: tile_template_id} = asset, export) do
    template = Map.get(export.tile_templates, tile_template_id, %{temp_tt_id: nil})
    Map.put(asset, :tile_template_id, template.temp_tt_id)
  end

  defp repoint_tile_template_id(asset, _export), do: asset

  defp repoint_script_slugs(asset, export, slug_type, temp_id_type, slug_pattern) do
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

  defp repoint_dungeon_item_slugs(%{dungeon: dungeon} = export) do
    case dungeon.state do
      %{"starting_equipment" => equipment} ->
        starting_equipment = \
        equipment
        |> Enum.map(fn slug -> export.items[slug].temp_item_id end)

        dungeon = %{ dungeon | state: %{ dungeon.state | "starting_equipment" => starting_equipment}}
        %{ export | dungeon: dungeon }
      _ ->
        export
    end
  end

  defp recalculate_tile_hashes(%{levels: levels, tiles: tiles} = export) do
    old_to_new_hash = Enum.map(tiles, fn {old_hash, tile_fields} ->
                        {old_hash, calculate_tile_hash(tile_fields)}
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

  defp calculate_tile_hash(tile_fields) do
    Base.encode64(:crypto.hash(:sha, inspect(Enum.sort(tile_fields))))
  end

  defp switch_keys(export, asset_key, temp_id_key) do
    assets = Map.get(export, asset_key)
             |> Enum.map(fn {_slug_or_id, asset} -> {Map.get(asset, temp_id_key), asset} end)
             |> Enum.into(%{})
    %{ export | asset_key => assets }
  end
end
